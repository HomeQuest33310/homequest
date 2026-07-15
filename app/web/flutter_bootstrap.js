{{flutter_js}}
{{flutter_build_config}}

const homeQuestBootstrap = document.getElementById('homequest-bootstrap');
const homeQuestBootstrapMessage = document.getElementById(
  'homequest-bootstrap-message',
);

function homeQuestSetMessage(message) {
  if (homeQuestBootstrapMessage) {
    homeQuestBootstrapMessage.textContent = message;
  }
}

function homeQuestShowError(error) {
  console.error('HomeQuest Web startup failed:', error);
  if (homeQuestBootstrap) {
    homeQuestBootstrap.classList.add('has-error');
  }
  homeQuestSetMessage(
    'Le portail ne peut pas s’ouvrir. Vérifiez votre connexion, puis réessayez.',
  );
}

function homeQuestHideLoader() {
  if (!homeQuestBootstrap) {
    return;
  }
  homeQuestBootstrap.classList.add('is-hidden');
  window.setTimeout(() => homeQuestBootstrap.remove(), 300);
}

async function homeQuestClearLegacyFlutterCache() {
  const cleanupKey = 'homequest_flutter_cache_cleanup_v1';
  if (window.localStorage.getItem(cleanupKey) === 'done') {
    return;
  }

  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      const homeQuestRegistrations = registrations.filter((registration) =>
        registration.scope.includes('/homequest/'),
      );
      await Promise.all(
        homeQuestRegistrations.map((registration) => registration.unregister()),
      );
    }

    if ('caches' in window) {
      const cacheNames = await caches.keys();
      const legacyFlutterCaches = new Set([
        'flutter-app-cache',
        'flutter-temp-cache',
        'flutter-app-manifest',
      ]);
      await Promise.all(
        cacheNames
          .filter((cacheName) => legacyFlutterCaches.has(cacheName))
          .map((cacheName) => caches.delete(cacheName)),
      );
    }

    window.localStorage.setItem(cleanupKey, 'done');
  } catch (error) {
    // Cache cleanup must never prevent the application from starting.
    console.warn('Legacy Flutter cache cleanup failed:', error);
  }
}

window.addEventListener('error', (event) => {
  homeQuestShowError(event.error ?? event.message);
});

window.addEventListener('unhandledrejection', (event) => {
  homeQuestShowError(event.reason);
});

window.setTimeout(() => {
  if (document.getElementById('homequest-bootstrap')) {
    homeQuestShowError(new Error('Flutter startup timed out'));
  }
}, 30000);

(async () => {
  await homeQuestClearLegacyFlutterCache();
  homeQuestSetMessage('Invocation des héros…');

  _flutter.loader.load({
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        homeQuestSetMessage('Le Royaume prend forme…');
        const appRunner = await engineInitializer.initializeEngine({
          renderer: 'canvaskit',
        });
        await appRunner.runApp();
        homeQuestHideLoader();
      } catch (error) {
        homeQuestShowError(error);
      }
    },
  });
})();
