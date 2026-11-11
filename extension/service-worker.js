/* ---------------------------------------------------------------------------
 * Auto Refresh — MV3 service worker
 *
 * Dua lapis pengaturan:
 *   1. Global  : default untuk semua tab. Diisi lewat managed policy
 *                (/etc/chromium/policies/managed/auto-refresh.json) sehingga
 *                bisa diatur dari env AUTO_REFRESH_SECONDS saat container start.
 *   2. Per-tab : override dari popup (disimpan di chrome.storage.local).
 *
 * Reload dilakukan dengan chrome.tabs.reload(tabId) — diuji jalan dari
 * service worker extension (tidak butuh debugger/webNavigation).
 * ------------------------------------------------------------------------- */

const DEFAULT_ALARM = 'auto-refresh-tick';
const MIN_SECONDS = 5;

// ---------------------------------------------------------------------------
// util
// ---------------------------------------------------------------------------
function policy() {
  try {
    const p = chrome.storage.managed;
    if (!p || !p.get) return Promise.resolve({});
    return new Promise((resolve) => p.get(null, (v) => resolve(v || {})));
  } catch (e) {
    return Promise.resolve({});
  }
}

function localGet(keys) {
  return new Promise((resolve) => chrome.storage.local.get(keys, (v) => resolve(v || {})));
}

function localSet(obj) {
  return new Promise((resolve) => chrome.storage.local.set(obj, resolve));
}

function tabsQuery(q) {
  return new Promise((resolve) => chrome.tabs.query(q, (t) => resolve(t || [])));
}

function tabsReload(tabId) {
  return new Promise((resolve) => {
    try {
      chrome.tabs.reload(tabId, { bypassCache: false }, () => {
        void chrome.runtime.lastError; // tab mungkin sudah ditutup
        resolve();
      });
    } catch (e) {
      resolve();
    }
  });
}

function canReload(url) {
  if (!url) return false;
  return /^(https?|file):/i.test(url);
}

// ---------------------------------------------------------------------------
// state
// ---------------------------------------------------------------------------
async function getState() {
  const [p, l] = await Promise.all([policy(), localGet(['globalSeconds', 'perTab', 'paused'])]);
  const globalSeconds = Number(p.seconds ?? l.globalSeconds ?? 0) || 0;
  const enforceGlobal = p.enforce === true;
  return {
    globalSeconds,
    enforceGlobal,
    perTab: l.perTab || {},
    paused: l.paused === true,
    hardReload: p.hardReload === true
  };
}

function effectiveSeconds(state, tabId) {
  const tabKey = String(tabId);
  const per = state.perTab[tabKey];
  if (per && typeof per.seconds === 'number' && !state.enforceGlobal) {
    return per.seconds > 0 ? per.seconds : 0;
  }
  return state.globalSeconds;
}

// ---------------------------------------------------------------------------
// tick: satu-satunya tempat reload terjadi
// ---------------------------------------------------------------------------
async function tick() {
  const state = await getState();
  if (state.paused) return;

  const tabs = await tabsQuery({});
  for (const tab of tabs) {
    if (typeof tab.id !== 'number' || tab.active === false && false) continue; // semua tab boleh
    if (!canReload(tab.url)) continue;
    const secs = effectiveSeconds(state, tab.id);
    if (!secs || secs < MIN_SECONDS) continue;

    const key = 'last:' + tab.id;
    const now = Date.now();
    const store = await localGet([key]);
    const last = Number(store[key] || 0);
    if (now - last < secs * 1000) continue;

    await localSet({ [key]: now });
    await tabsReload(tab.id);
  }
}

// Alarm 1 menit hanya "pemicu"; keputusan interval tetap per-tab (bisa 5 detik).
// chrome.alarms minimum 30 detik pada MV3, jadi kita pakai 0.5 menit + tick.
function ensureAlarm() {
  chrome.alarms.get(DEFAULT_ALARM, (a) => {
    if (!a) chrome.alarms.create(DEFAULT_ALARM, { periodInMinutes: 0.5 });
  });
}

chrome.runtime.onInstalled.addListener(() => { ensureAlarm(); });
chrome.runtime.onStartup.addListener(() => { ensureAlarm(); });
chrome.alarms.onAlarm.addListener((alarm) => { if (alarm.name === DEFAULT_ALARM) tick(); });

// interval pendek (< 30 detik) butuh tick lebih rapat: pakai setTimeout di SW
// selama SW hidup. SW dibangunkan lagi oleh alarm kalau sempat mati.
let fastTimer = null;
function scheduleFastTick() {
  if (fastTimer) clearTimeout(fastTimer);
  fastTimer = setTimeout(async () => {
    try { await tick(); } catch (e) {}
    scheduleFastTick();
  }, 5000);
}

// ---------------------------------------------------------------------------
// messaging (dipakai popup)
// ---------------------------------------------------------------------------
chrome.runtime.onMessage.addListener((msg, sender, reply) => {
  (async () => {
    const state = await getState();

    if (msg?.type === 'get') {
      const [tab] = await tabsQuery({ active: true, currentWindow: true });
      reply({
        ok: true,
        globalSeconds: state.globalSeconds,
        enforceGlobal: state.enforceGlobal,
        paused: state.paused,
        tabSeconds: tab && tab.id ? (state.perTab[String(tab.id)]?.seconds ?? null) : null,
        tabUrl: tab?.url || ''
      });
      return;
    }

    if (msg?.type === 'setGlobal') {
      const secs = Math.max(0, Math.min(86400, Number(msg.seconds) || 0));
      await localSet({ globalSeconds: secs });
      await tick();
      reply({ ok: true, globalSeconds: secs });
      return;
    }

    if (msg?.type === 'setTab') {
      const [tab] = await tabsQuery({ active: true, currentWindow: true });
      if (!tab || typeof tab.id !== 'number') { reply({ ok: false }); return; }
      const perTab = { ...state.perTab };
      const secs = Math.max(0, Math.min(86400, Number(msg.seconds) || 0));
      if (secs === 0) delete perTab[String(tab.id)];
      else perTab[String(tab.id)] = { seconds: secs, url: tab.url || '' };
      await localSet({ perTab });
      reply({ ok: true, tabSeconds: secs || null });
      return;
    }

    if (msg?.type === 'pause') {
      await localSet({ paused: !!msg.paused });
      reply({ ok: true, paused: !!msg.paused });
      return;
    }

    if (msg?.type === 'refreshNow') {
      const [tab] = await tabsQuery({ active: true, currentWindow: true });
      if (tab && typeof tab.id === 'number') await tabsReload(tab.id);
      reply({ ok: true });
      return;
    }

    reply({ ok: false, error: 'unknown' });
  })();
  return true; // async reply
});

chrome.tabs.onRemoved.addListener(async (tabId) => {
  const state = await getState();
  const key = String(tabId);
  if (state.perTab[key]) {
    const perTab = { ...state.perTab };
    delete perTab[key];
    await localSet({ perTab, ['last:' + tabId]: undefined });
  }
});

// tab baru: kalau global aktif, langsung dicatat supaya tidak reload di detik 0
chrome.tabs.onCreated.addListener(() => { ensureAlarm(); });

ensureAlarm();
scheduleFastTick();
