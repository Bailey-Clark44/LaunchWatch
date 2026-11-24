// LaunchWatch offline worker.
//
// Pages always try the network first, so a deploy reaches everyone on their
// next visit (the stale-app problem in Edge came from caching these). Only when
// the network is unavailable does the saved copy open instead.
//
// Files whose URL carries a build stamp (?v=) never change, so they come from
// the cache. Fonts, the CanvasKit renderer and launch images are cached as they
// load. Sign-in, Firestore and calendar requests are never touched: Firestore
// keeps its own offline copy in IndexedDB.
//
// scripts/stamp-web.mjs replaces __BUILD__ with the build hash at deploy time.
const BUILD = '__BUILD__';
const CORE = `lw-core-${BUILD}`;
const RUNTIME = 'lw-runtime-v1';
const IMAGES = 'lw-images-v1';
const IMAGE_LIMIT = 250;
const INDEX = '/index.html';

const PRECACHE = [
  INDEX,
  `/flutter_bootstrap.js?v=${BUILD}`,
  `/main.dart.js?v=${BUILD}`,
  '/manifest.json',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CORE)
      .then((cache) => cache.addAll(PRECACHE.map((url) => new Request(url, { cache: 'reload' }))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keep = new Set([CORE, RUNTIME, IMAGES]);
    for (const key of await caches.keys()) {
      if (key.startsWith('lw-') && !keep.has(key)) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

// The page sends the files it loaded before this worker took control (the
// renderer, fonts, asset manifests), so the very first visit works offline.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'cache-urls' || !Array.isArray(data.urls)) return;
  event.waitUntil(Promise.all(data.urls.map(async (url) => {
    const request = new Request(url);
    const rule = ruleFor(request);
    if (!rule || rule === 'page') return;
    const name = rule === 'image' ? IMAGES : rule === 'core' ? CORE : RUNTIME;
    const cache = await caches.open(name);
    if (await cache.match(request)) return;
    try {
      const response = await fetch(request);
      if (response.ok) await cache.put(request, response);
    } catch (_) {}
  })));
});

const PASS_THROUGH_HOSTS = [
  'firestore.googleapis.com',
  'identitytoolkit.googleapis.com',
  'securetoken.googleapis.com',
  'firebaseinstallations.googleapis.com',
  'fcmregistrations.googleapis.com',
  'www.googleapis.com',
  'apis.google.com',
  'accounts.google.com',
];
const IMAGE_EXT = /\.(?:png|jpe?g|webp|gif|svg|avif)$/i;

function ruleFor(request) {
  if (request.method !== 'GET') return null;
  const url = new URL(request.url);
  if (url.protocol !== 'https:' && url.hostname !== 'localhost') return null;
  if (PASS_THROUGH_HOSTS.includes(url.hostname)) return null;
  if (url.pathname.startsWith('/__/') || url.pathname.startsWith('/cal/')) return null;
  if (request.mode === 'navigate') return 'page';
  const sameOrigin = url.origin === self.location.origin;
  if (sameOrigin && url.searchParams.has('v')) return 'core';
  if (sameOrigin && /\/(?:sw|firebase-messaging-sw)\.js$/.test(url.pathname)) return null;
  if (sameOrigin) return 'runtime';
  if (url.hostname === 'fonts.gstatic.com' || url.hostname === 'fonts.googleapis.com') return 'static';
  if (url.hostname === 'www.gstatic.com' && url.pathname.startsWith('/flutter-canvaskit/')) return 'static';
  if (request.destination === 'image' || IMAGE_EXT.test(url.pathname)) return 'image';
  return null;
}

self.addEventListener('fetch', (event) => {
  const rule = ruleFor(event.request);
  if (!rule) return;
  if (rule === 'page') event.respondWith(page(event.request));
  else if (rule === 'core') event.respondWith(cacheFirst(event.request, CORE));
  else if (rule === 'static') event.respondWith(cacheFirst(event.request, RUNTIME));
  else if (rule === 'image') event.respondWith(cacheFirst(event.request, IMAGES, IMAGE_LIMIT));
  else event.respondWith(staleWhileRevalidate(event.request, RUNTIME));
});

async function page(request) {
  const cache = await caches.open(CORE);
  try {
    const response = await fetch(request);
    // Every app URL serves the same index.html, so one saved copy covers them all.
    if (response.ok && (response.headers.get('content-type') || '').includes('text/html')) {
      await cache.put(INDEX, response.clone());
    }
    return response;
  } catch (error) {
    const saved = await cache.match(INDEX);
    if (saved) return saved;
    throw error;
  }
}

async function cacheFirst(request, name, limit) {
  const cache = await caches.open(name);
  const saved = await cache.match(request);
  if (saved) return saved;
  const response = await fetch(request);
  if (response.ok || response.type === 'opaque') {
    await cache.put(request, response.clone());
    if (limit) trim(cache, limit);
  }
  return response;
}

async function staleWhileRevalidate(request, name) {
  const cache = await caches.open(name);
  const saved = await cache.match(request);
  const fresh = fetch(request).then(async (response) => {
    if (response.ok) await cache.put(request, response.clone());
    return response;
  });
  if (saved) {
    fresh.catch(() => {});
    return saved;
  }
  return fresh;
}

async function trim(cache, limit) {
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - limit; i++) await cache.delete(keys[i]);
}
