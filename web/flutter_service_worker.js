'use strict';

// Self-destructing Service Worker
// Automatically unregisters itself, wipes CacheStorage, and reloads client tabs.
self.addEventListener('install', function () {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    self.registration.unregister().then(function () {
      if ('caches' in self) {
        return caches.keys().then(function (names) {
          return Promise.all(names.map(function (n) { return caches.delete(n); }));
        });
      }
    }).then(function () {
      return self.clients.matchAll({ type: 'window' });
    }).then(function (clients) {
      clients.forEach(function (client) {
        if (client.url && 'navigate' in client) {
          client.navigate(client.url);
        }
      });
    })
  );
});
