# Recuperación parcial de Cloudflare — EFFETTO LAB

- Worker: `long-heart-03db`
- Cuenta Cloudflare: `1ce5f80c772cc71aee05f582e9e22432`
- Versión activa recuperada: `47`
- ID de versión: `ce651bb2-db0a-4644-b2fe-0d51687179a1`
- Fecha de publicación: `2026-11-22T20:51:46.835842Z`
- Fecha de compatibilidad: `2026-11-18`
- Binding detectado: `ASSETS` (Cloudflare Workers Static Assets)
- Origen de despliegue registrado: `api`

## Alcance de este respaldo

Este commit conserva el módulo Worker recuperado desde la versión activa de Cloudflare en `worker.js`. **No es todavía una copia completa y desplegable de la aplicación.**

Cloudflare devolvió el módulo del Worker, pero no incluyó en la descarga el contenido de los archivos estáticos asociados al binding `ASSETS`. Esos archivos (por ejemplo, `index.html`, `config.js`, manifiesto, iconos y recursos) deben recuperarse y compararse por separado antes de considerar sincronizado el repositorio.

## Seguridad y producción

- Esta rama es un respaldo de recuperación; no debe desplegarse.
- No se modificó el Worker productivo, sus rutas, el subdominio `workers.dev` ni la configuración de producción.
- No se guardaron secretos ni valores de credenciales.
- No se debe configurar CI/CD hasta validar los assets, la configuración de Supabase y las variables/bindings necesarios.

