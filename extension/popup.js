/* popup Auto Refresh — kontrol per-tab & global */
const $ = (id) => document.getElementById(id);

function send(msg) {
  return new Promise((resolve) => {
    try {
      chrome.runtime.sendMessage(msg, (r) => { void chrome.runtime.lastError; resolve(r || {}); });
    } catch (e) { resolve({}); }
  });
}

function setStatus(text) { $('status').textContent = text; }

async function refresh() {
  const s = await send({ type: 'get' });
  $('tab').value = s.tabSeconds ?? '';
  $('glob').value = s.globalSeconds || '';
  $('url').textContent = s.tabUrl || '(tab tanpa URL)';
  if (s.enforceGlobal) $('tab').disabled = true;
  $('pause').textContent = s.paused ? 'Resume' : 'Pause';
  $('pause').dataset.paused = s.paused ? '1' : '0';
  setStatus(
    s.paused ? 'Dijeda.' :
    s.globalSeconds ? `Semua tab: tiap ${s.globalSeconds}s` :
    s.tabSeconds ? `Tab ini: tiap ${s.tabSeconds}s` : 'Nonaktif.'
  );
}

$('setTab').addEventListener('click', async () => {
  const secs = Number($('tab').value) || 0;
  await send({ type: 'setTab', seconds: secs });
  setStatus(secs ? `Tab ini: tiap ${secs}s` : 'Auto refresh tab ini dimatikan.');
  refresh();
});

$('setGlob').addEventListener('click', async () => {
  const secs = Number($('glob').value) || 0;
  await send({ type: 'setGlobal', seconds: secs });
  setStatus(secs ? `Semua tab: tiap ${secs}s` : 'Auto refresh global dimatikan.');
  refresh();
});

$('pause').addEventListener('click', async () => {
  const paused = $('pause').dataset.paused === '1';
  await send({ type: 'pause', paused: !paused });
  refresh();
});

$('now').addEventListener('click', async () => {
  await send({ type: 'refreshNow' });
  setStatus('Halaman di-reload.');
});

refresh();
