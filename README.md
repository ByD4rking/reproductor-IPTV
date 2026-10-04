# reproductor-IPTV

Base Flutter independiente para un reproductor IPTV resiliente.

## 📦 Descargas

Los instaladores se generan **automáticamente dentro de este mismo repositorio** mediante GitHub Actions. El usuario final no necesita instalar Flutter, SDKs ni ejecutar comandos.

**Descargar:** https://github.com/ByD4rking/reproductor-IPTV/releases

Cada release puede incluir:

- **Android APK** — teléfonos Android.
- **Android TV / Google TV APK** — televisores y TV Box Android.
- **Fire TV APK** — Amazon Fire TV / Fire OS.
- **LG webOS IPK** — televisores LG.
- **Samsung Tizen WGT** — televisores Samsung, cuando el runner y certificado de firma Tizen estén configurados.

Los archivos se generan y validan en GitHub Actions y quedan publicados como assets permanentes de la release. No se distribuyen listas IPTV ni se modifican las listas externas.

## Estado de construcción

| Plataforma | Paquete | Generación |
|---|---|---|
| Android | `.apk` | 🟢 Automática |
| Android TV / Google TV | `.apk` | 🟢 Automática |
| Fire TV | `.apk` | 🟢 Automática |
| LG webOS | `.ipk` | 🟢 Automática |
| Samsung Tizen | `.wgt` | 🟡 Requiere runner/certificado Tizen |

La prueba física en un televisor real se mantiene separada de la construcción: que un paquete compile correctamente no significa que se haya probado en hardware real.

## Arquitectura

El núcleo Dart/Flutter permanece separado de los adaptadores de plataforma. El pipeline construye los instaladores desde el mismo commit para evitar que las versiones de Android, LG y Samsung diverjan.

## Implementado

- Dominio separado de fuentes.
- Parser M3U con límites y validación.
- Estados de reproducción con protección contra eventos obsoletos.
- Recuperación escalonada.
- Circuit breaker.
- Redacción de secretos.
- Pruebas automatizadas.
- Builds multiplataforma reproducibles.
- Publicación automática de instaladores en GitHub Releases.
