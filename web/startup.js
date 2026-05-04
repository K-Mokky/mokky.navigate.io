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
})().catch((error) => {
  console.error('Flutter cache reset failed; loading app anyway.', error);
  const bootstrap = document.createElement('script');
  bootstrap.src = 'flutter_bootstrap.js';
  bootstrap.async = true;
  document.body.appendChild(bootstrap);
});
