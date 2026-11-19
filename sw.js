self.addEventListener('install', (e) => {
  console.log('[Service Worker] Instalado con éxito');
});

self.addEventListener('fetch', (e) => {
  // Maneja las peticiones web en segundo plano
});