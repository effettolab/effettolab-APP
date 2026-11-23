# EFFETTO LAB — Aplicación de gestión

Este repositorio contiene la versión recuperada de la aplicación que estaba activa en Cloudflare el 23 de noviembre de 2026.

## Fuente oficial del despliegue

- Worker: `long-heart-03db`
- URL pública: https://long-heart-03db.nangoespinal1.workers.dev
- Plataforma: Cloudflare Workers + Static Assets
- Frontend: `public/`
- Worker: `worker.js`
- Configuración de despliegue: `wrangler.toml`
- Base de datos: Supabase `bwslpdrfvetwdlyxshxe`

La carpeta `cloudflare-recovery/` conserva la copia original recuperada como respaldo histórico. El despliegue automático utiliza los archivos de la raíz y `public/`, no la carpeta de respaldo.

## Despliegue automático

El workflow `.github/workflows/deploy-worker.yml` publica el Worker y los archivos estáticos cuando se integra un cambio en `main`, o cuando se ejecuta manualmente desde GitHub Actions.

Antes de activar el primer despliegue automático, crea este secreto en GitHub:

1. Abre Settings → Secrets and variables → Actions.
2. Crea un Repository secret llamado `CLOUDFLARE_API_TOKEN`.
3. Usa un token de Cloudflare con permiso **Edit Cloudflare Workers**, limitado a la cuenta de EFFETTO LAB.
4. No escribas el token en archivos del repositorio, commits, mensajes ni código.

El ID de cuenta no es secreto y ya está declarado en `wrangler.toml`.

## Flujo de trabajo recomendado

1. Trabajar en una rama distinta de `main`.
2. Revisar los cambios y probarlos antes de integrarlos.
3. Crear un Pull Request hacia `main`.
4. Al integrar el Pull Request, GitHub Actions despliega automáticamente en el Worker existente.
5. Comprobar la URL pública y los módulos principales después del despliegue.

## Seguridad y datos

- La aplicación utiliza la clave publishable de Supabase en `public/config.js`; es una clave pública de frontend y la protección depende de RLS y sus políticas.
- No se deben guardar claves secretas de Supabase ni tokens de Cloudflare en el repositorio.
- Las fotos y comprobantes existentes continúan almacenados en Supabase Storage; este repositorio no contiene esos datos.
- No se realizan migraciones ni cambios de esquema de Supabase como parte del despliegue del frontend.

## Recuperación

La carpeta `cloudflare-recovery/` conserva los archivos recuperados del Worker y de la aplicación publicada, junto con la documentación de la recuperación.
