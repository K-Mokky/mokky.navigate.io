const startupStatus = document.getElementById('startup-status');
const setStartupStatus = (message) => {
  if (startupStatus) startupStatus.textContent = message;
};
const watchFlutterBoot = () => {
  const startedAt = Date.now();
  const timer = window.setInterval(() => {
    const flutterRoot = document.querySelector(
      'flutter-view, flt-glass-pane, flt-scene-host',
    );
    if (flutterRoot) {
      if (startupStatus) startupStatus.remove();
      window.clearInterval(timer);
      return;
    }
    if (Date.now() - startedAt > 15000) {
      setStartupStatus(
        '앱 로딩이 오래 걸리고 있어요. 새로고침 후에도 계속되면 Console 오류를 확인해주세요.',
      );
      window.clearInterval(timer);
    }
  }, 500);
};

(async () => {
  // This app is hosted as an always-online Flutter web app. Old Flutter
  // service workers can keep serving stale JS/font manifests while the
  // current page is still controlled, so detach them before bootstrapping.
  const resetKey = 'navigate-sw-reset-v2';
  let hadController = false;

  if ('serviceWorker' in navigator) {
    hadController = Boolean(navigator.serviceWorker.controller);
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations.map((registration) => registration.unregister()),
    );
  }

  if ('caches' in window) {
    const keys = await caches.keys();
    await Promise.all(
      keys
        .filter((key) =>
          key.startsWith('flutter-app-cache') || key.includes('flutter'),
        )
        .map((key) => caches.delete(key)),
    );
  }

  if (hadController && sessionStorage.getItem(resetKey) !== 'done') {
    sessionStorage.setItem(resetKey, 'done');
    const freshUrl = new URL(window.location.href);
    freshUrl.searchParams.set('fresh', resetKey);
    window.location.replace(freshUrl.toString());
    return;
  }

  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  document.body.appendChild(bootstrap);
  watchFlutterBoot();
})().catch((error) => {
  console.error('Flutter cache reset failed; loading app anyway.', error);
  setStartupStatus('앱 캐시 정리 중 문제가 있었지만 계속 불러오는 중이에요…');
  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  document.body.appendChild(bootstrap);
  watchFlutterBoot();
});
