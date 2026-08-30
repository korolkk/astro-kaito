const CACHE = 'kaitohub-v2';
const PRECACHE_ASSETS = [
	'/',
	'/blog/',
	'/about/',
	'/ai-tools/',
];

self.addEventListener('install', function(e) {
	e.waitUntil(
		caches.open(CACHE).then(function(cache) {
			return cache.addAll(PRECACHE_ASSETS);
		}).then(function() {
			return self.skipWaiting();
		})
	);
});

self.addEventListener('activate', function(e) {
	e.waitUntil(
		caches.keys().then(function(keys) {
			return Promise.all(
				keys.filter(function(k) { return k !== CACHE; })
					.map(function(k) { return caches.delete(k); })
			);
		}).then(function() {
			return self.clients.claim();
		})
	);
});

self.addEventListener('fetch', function(e) {
	var req = e.request;
	if (req.method !== 'GET') return;

	var url = new URL(req.url);
	if (url.origin !== location.origin) return;

	// 页面导航：网络优先，保证部署后能拿到最新页面；离线时才回退缓存
	if (req.mode === 'navigate') {
		e.respondWith(
			fetch(req).then(function(response) {
				var clone = response.clone();
				caches.open(CACHE).then(function(cache) {
					cache.put(req, clone);
				});
				return response;
			}).catch(function() {
				return caches.match(req).then(function(cached) {
					return cached || caches.match('/');
				});
			})
		);
		return;
	}

	// 静态资源（_astro/* 带 hash）：缓存优先，离线可用
	e.respondWith(
		caches.match(req).then(function(resp) {
			return resp || fetch(req).then(function(response) {
				if (response.ok) {
					var clone = response.clone();
					caches.open(CACHE).then(function(cache) {
						cache.put(req, clone);
					});
				}
				return response;
			});
		})
	);
});
