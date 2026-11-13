const CACHE = "mma-clock-v21"
const FILES = [
  "./",
  "./index.html",
  "./app.css",
  "./app.js",
  "./engine.js",
  "./i18n.js",
  "./fonts/BarlowCondensed-Bold.ttf",
  "./fonts/BarlowCondensed-SemiBold.ttf",
  "./fonts/Barlow-Medium.ttf",
  "./fonts/Barlow-SemiBold.ttf",
  "./manifest.webmanifest",
  "./bell.m4a",
  "./icon-180.png",
  "./icon-192.png",
  "./icon-512.png",
]

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)))).then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return
  event.respondWith(
    fetch(event.request).then((response) => {
      if (response.ok) {
        const copy = response.clone()
        caches.open(CACHE).then((cache) => cache.put(event.request, copy))
      }
      return response
    }).catch(() => caches.match(event.request))
  )
})
