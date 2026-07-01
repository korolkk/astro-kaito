const CACHE = 'kaitohub-v1';
const ASSETS = [
	'/',
	'/blog/',
	'/about/',
	'/ai-tools/',
];

self.addEventListener('install', function(e) {
	e.waitUntil(
		caches.open(CACHE).then(function(cache) {
			return cache.addAll(ASSETS);
		})
	);
});

self.addEventListener('fetch', function(e) {
	e.respondWith(
		caches.match(e.request).then(function(resp) {
			return resp || fetch(e.request).then(function(response) {
				if (response.ok && e.request.method === 'GET') {
					var clone = response.clone();
					caches.open(CACHE).then(function(cache) {
						cache.put(e.request, clone);
					});
				}
				return response;
			});
		})
	);
});
