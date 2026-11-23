# Recuperación de Cloudflare — EFFETTO LAB

- Worker: `long-heart-03db`
- Versión activa recuperada: `47`
- ID de versión: `ce651bb2-db0a-4644-b2fe-0d51687179a1`
- Publicación: `2026-11-22T20:51:46.835842Z`
- Fecha de compatibilidad: `2026-11-18`
- Binding de archivos estáticos: `ASSETS`
- Dominio público consultado: `long-heart-03db.nangoespinal1.workers.dev`

## Archivos recuperados

Los siguientes archivos se leyeron desde la aplicación que está sirviendo Cloudflare y se guardaron en esta carpeta:

- `worker.js`: módulo del Worker versión 47
- `index.html`: HTML publicado (incluye CSS y JavaScript integrados)
- `config.js`: configuración pública del frontend
- `manifest.json`: manifiesto de la PWA
- `sw.js`: Service Worker
- `assets/Logo.png`: logo de la aplicación
- `icon-192.png` y `icon-512.png`: iconos de la PWA

La configuración del frontend apunta a `https://bwslpdrfvetwdlyxshxe.supabase.co`, que coincide con el proyecto Supabase identificado en la auditoría previa.

## Alcance y cautelas

Esta es una copia de recuperación de los archivos servidos por la versión activa, no una configuración lista para despliegue automático. Los archivos se conservan dentro de `cloudflare-recovery/` para no reemplazar ni mezclar la versión antigua que vive en la raíz de `main`.

Antes de activar CI/CD hay que revisar el esquema y las funciones de Supabase utilizadas por esta versión, comprobar los recursos cargados dinámicamente (por ejemplo, fotos y comprobantes almacenados en Supabase Storage), verificar los bindings y probar una compilación/preview aislada. El HTML contiene recursos remotos de terceros que también deben permanecer disponibles.

## Seguridad y producción

- Esta rama es un respaldo; no debe desplegarse directamente.
- No se modificó el Worker productivo, su nombre, el subdominio `workers.dev`, ni sus rutas o configuración.
- No se modificó la rama `main`.
- No se configuró todavía un pipeline automático.
- No se copiaron tokens privados ni secretos de servidor. La clave publishable de Supabase es una clave pública de frontend, pero debe mantenerse protegida por RLS y políticas correctas.
