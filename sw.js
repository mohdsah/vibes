// =============================================
// VIBES Service Worker — PWA offline support
// =============================================

const CACHE_NAME = 'vibes-v1';
const STATIC_CACHE = 'vibes-static-v1';

// Files to cache for offline
const STATIC_FILES = [
  '/',
  '/index.html',
  '/auth.html',
  '/search.html',
  '/profile.html',
  '/notifications.html',
  '/upload.html',
  '/video.html',
  '/live-list.html',
  '/leaderboard.html',
  '/trending.html',
  '/settings.html',
  '/wallet.html',
  '/topup.html',
  '/js/supabase-config.js',
  '/js/nav.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://fonts.googleapis.com/css2?family=Bebas+Neue&family=DM+Sans:wght@300;400;500;600&display=swap',
];

// Install — cache static files
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(STATIC_CACHE).then(cache => {
      return Promise.allSettled(
        STATIC_FILES.map(url => cache.add(url).catch(() => {}))
      );
    })
  );
});

// Activate — clean old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k !== CACHE_NAME && k !== STATIC_CACHE)
          .map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// Fetch — network first, fall back to cache
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // Skip non-GET and Supabase API calls (always need fresh data)
  if (event.request.method !== 'GET') return;
  if (url.hostname.includes('supabase.co')) return;

  // For HTML pages — network first, cache fallback
  if (event.request.destination === 'document') {
    event.respondWith(
      fetch(event.request)
        .then(res => {
          const clone = res.clone();
          caches.open(STATIC_CACHE).then(c => c.put(event.request, clone));
          return res;
        })
        .catch(() => caches.match(event.request).then(cached => cached || caches.match('/index.html')))
    );
    return;
  }

  // For static assets — cache first
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(res => {
        if (!res || res.status !== 200) return res;
        const clone = res.clone();
        caches.open(STATIC_CACHE).then(c => c.put(event.request, clone));
        return res;
      }).catch(() => cached);
    })
  );
});

// Push notifications
self.addEventListener('push', event => {
  if (!event.data) return;
  let data = {};
  try { data = event.data.json(); } catch(e) { data = { title: 'VIBES', body: event.data.text() }; }

  event.waitUntil(
    self.registration.showNotification(data.title || 'VIBES 🎬', {
      body: data.body || 'Kau ada notifikasi baru!',
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-96.png',
      tag: data.tag || 'vibes-notif',
      data: { url: data.url || '/notifications.html' },
      vibrate: [200, 100, 200],
    })
  );
});

// Notification click
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const url = event.notification.data?.url || '/notifications.html';
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(list => {
      const existing = list.find(c => c.url.includes(self.location.origin));
      if (existing) { existing.focus(); existing.navigate(url); }
      else clients.openWindow(url);
    })
  );
});
