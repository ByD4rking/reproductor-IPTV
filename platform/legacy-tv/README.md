# Implementación TV heredada (archivada)

Esta carpeta conserva el prototipo que estaba ubicado incorrectamente en el repositorio de listas IPTV.

**No es el flujo de compilación activo.** Los builds mantenidos del reproductor deben ejecutarse desde `.github/workflows/tv-packages.yml` y los perfiles vigentes de `platform/tizen/` y `platform/webos/`. Fire TV debe integrarse al empaquetado principal antes de considerar este prototipo un producto listo para publicar.

## Contenido preservado

- Prototipo Fire TV basado en Android WebView/Gradle.
- Reproductor HTML5 compartido y prueba estática de reconexión.
- Perfiles y scripts de empaquetado heredados para Tizen y webOS.

## Limitaciones conocidas

- El prototipo carga el catálogo desde el repositorio de listas; no genera ni modifica listas.
- La prueba `tests/reconnect_test.py` solo inspecciona texto/código, no demuestra reproducción estable ni recuperación real del stream.
- Los scripts heredados no equivalen a un build exitoso: requieren SDK y herramientas de plataforma.
- No se declara compatibilidad física verificada. Fire TV, Samsung Tizen y LG webOS necesitan builds y pruebas reales en sus dispositivos.

Esta carpeta se conserva como referencia para migración controlada; no se debe publicar como artefacto oficial ni sustituir la implementación Flutter activa sin auditoría y pruebas.
