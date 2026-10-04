# reproductor-IPTV

> **Reproductor IPTV multiplataforma, resiliente y preparado para distribución automática.**

Reproductor IPTV construido con Flutter, orientado a una experiencia estable en dispositivos móviles, televisores y futuras plataformas de escritorio. El proyecto separa el núcleo de reproducción de los adaptadores específicos de cada plataforma y utiliza **GitHub Actions** como sistema central de construcción y publicación.

[![Build](https://github.com/ByD4rking/reproductor-IPTV/actions/workflows/tv-packages.yml/badge.svg)](https://github.com/ByD4rking/reproductor-IPTV/actions/workflows/tv-packages.yml)
[![Releases](https://img.shields.io/github/v/release/ByD4rking/reproductor-IPTV?display_name=tag&sort=semver)](https://github.com/ByD4rking/reproductor-IPTV/releases)
[![License](https://img.shields.io/github/license/ByD4rking/reproductor-IPTV)](https://github.com/ByD4rking/reproductor-IPTV/blob/main/LICENSE)

---

## 📥 Descargas para usuarios

Los instaladores oficiales se publican directamente en **GitHub Releases**.

**Flujo para el usuario:**

**Entrar → elegir plataforma → descargar → instalar.**

No es necesario instalar Flutter, Android Studio, SDKs ni ejecutar comandos para utilizar una versión publicada.

### Plataformas

| Plataforma | Formato | Estado |
|---|---:|---|
| 📱 Android | `.apk` | 🟢 Generación automática |
| 📺 Android TV / Google TV | `.apk` | 🟢 Generación automática |
| 📦 TV Box Android | `.apk` | 🟢 Compatible con el perfil Android TV |
| 🔥 Fire TV / Fire OS | `.apk` | 🟢 Generación automática |
| 📡 Chromecast con Google TV | `.apk` | 🟢 Usa el perfil Android TV |
| 📺 LG webOS | `.ipk` | 🔵 Paquete automático / 🟡 prueba física pendiente |
| 📺 Samsung Tizen | `.wgt` | 🟡 Runner + certificado Tizen |
| 🪟 Windows | Instalador | 🟡 En implementación |
| 🐧 Linux | AppImage/paquete | 🟡 En implementación |
| 🍎 macOS | DMG/PKG | 🟡 En implementación |
| 📺 Roku | Paquete Roku | 🟡 En implementación |
| 📱 iPhone / iPad | Apple | 🟡 Requiere toolchain y firma Apple |
| 🍎 Apple TV / tvOS | Apple | 🟡 Requiere toolchain y firma Apple |

> **Importante:** el estado 🟢 significa que el artefacto puede ser generado y validado por el pipeline correspondiente. Una compilación correcta no sustituye una prueba física en un dispositivo real.

### 🔗 Releases oficiales

**[Abrir Descargas / Releases](https://github.com/ByD4rking/reproductor-IPTV/releases)**

En cada Release los archivos se publican con nombres explícitos para que no tengas que adivinar qué descargar:

| Dispositivo | Archivo que debes buscar |
|---|---|
| 📱 Android teléfono/tablet | `Reproductor-IPTV-<versión>-Android-*.apk` |
| 📺 Android TV / Google TV / TV Box | `Reproductor-IPTV-<versión>-AndroidTV-GoogleTV-*.apk` |
| 🔥 Fire TV / Fire OS | `Reproductor-IPTV-<versión>-FireTV-FireOS-*.apk` |
| 🟦 LG Smart TV | `Reproductor-IPTV-<versión>-LG-webOS.ipk` |
| 🟩 Samsung Smart TV | `Reproductor-IPTV-<versión>-Samsung-Tizen.wgt` |

**Regla de descarga:** entra a la Release, identifica tu dispositivo en la tabla y descarga solamente ese grupo de archivos.

Las versiones anteriores permanecen disponibles para recuperación, comparación y pruebas.

---

## 🔖 Sistema de versiones

El proyecto utiliza **Semantic Versioning (SemVer)**:

`MAJOR.MINOR.PATCH`

Ejemplos:

- `v1.0.0` — primera versión estable.
- `v1.0.1` — corrección de errores.
- `v1.1.0` — nuevas funcionalidades compatibles.
- `v2.0.0` — cambios importantes de arquitectura o compatibilidad.

El número de versión del proyecto se mantiene en `pubspec.yaml` y las futuras Releases deben conservar una correspondencia clara entre:

**código → versión → build → artefactos publicados.**

Los artefactos de una Release deben proceder del mismo commit para evitar que distintas plataformas queden desincronizadas.

### Canales previstos

- **Stable** — versión recomendada para usuarios finales.
- **Beta** — funciones nuevas antes de estabilización.
- **Release Candidate (RC)** — candidata a convertirse en estable.

Las versiones experimentales no deben presentarse como releases estables.

---

## 🚀 Publicación automática

GitHub Actions centraliza la generación de instaladores.

Flujo previsto:

```text
Cambio en el código
       ↓
Validaciones y tests
       ↓
Build por plataforma
       ↓
Validación del artefacto
       ↓
Generación de Release
       ↓
Instaladores publicados
       ↓
Usuario descarga su plataforma
```

El objetivo es que el repositorio sea el **centro único de distribución** del reproductor.

No se deben publicar manualmente binarios construidos fuera del pipeline sin una razón documentada.

---

## 🏗️ Arquitectura

El proyecto mantiene una separación entre:

- **Core/Dominio** — lógica común del reproductor.
- **Fuentes y playlists** — ingestión y validación.
- **Reproducción** — estados, recuperación y control de errores.
- **Adaptadores de plataforma** — integración específica de Android, webOS, Tizen y futuros targets.
- **Tooling de build** — empaquetado y validación.
- **GitHub Actions** — automatización de CI/CD y Releases.

Esta separación permite añadir plataformas sin duplicar innecesariamente la lógica principal.

---

## 🛡️ Resiliencia y seguridad

Entre las capacidades implementadas actualmente se incluyen:

- Parser M3U con límites y validación.
- Protección frente a eventos de reproducción obsoletos.
- Recuperación escalonada.
- Circuit breaker.
- Redacción de secretos.
- Validaciones automatizadas.
- Builds reproducibles desde el repositorio.
- Separación de los adaptadores de plataforma.

La estabilidad del reproductor y la recuperación ante fallos forman parte del diseño, no son únicamente características de la interfaz.

---

## 📺 Compatibilidad de plataformas

### Android / Android TV / Google TV / TV Box

Android utiliza paquetes `.apk`. Los perfiles se separan para adaptar la experiencia de teléfonos y dispositivos TV.

### Fire TV

Fire TV / Fire OS utiliza el ecosistema Android, por lo que se genera un APK específico para este perfil.

### Chromecast

**Chromecast con Google TV** utiliza Android TV/Google TV y puede utilizar el APK correspondiente.

Los Chromecast tradicionales que funcionan únicamente como receptores de casting **no instalan APKs**; se consideran un escenario de casting distinto.

### LG webOS

LG utiliza paquetes `.ipk`. El pipeline prepara el contenido web, aplica un arranque de compatibilidad CanvasKit para navegadores webOS con capacidades gráficas limitadas y genera el paquete nativo mediante las herramientas de webOS. Además, el paquete incorpora un diagnóstico visible si Flutter no consigue crear la superficie de renderizado. Esto mejora la recuperación frente a una pantalla negra, pero la validación física por modelo de TV sigue siendo necesaria.

### Samsung Tizen

Samsung utiliza paquetes `.wgt`. La generación requiere un runner Tizen y un perfil/certificado de firma configurado en GitHub Actions.

### Roku

Roku utiliza su propio ecosistema y empaquetado; no se reutiliza el APK de Android. El soporte se incorporará mediante un pipeline específico de Roku.

### Apple

iPhone/iPad y Apple TV/tvOS requieren herramientas y firma de Apple. No se publicará un supuesto `.ipa` o paquete tvOS como "listo" mientras no exista una cadena real de build y distribución con las credenciales correspondientes.

---

## 🧪 Calidad y validación

El pipeline debe validar como mínimo:

- existencia del artefacto esperado;
- extensión y formato correcto;
- cantidad esperada de paquetes;
- metadatos de versión;
- consistencia entre commit y Release;
- fallos de build;
- ausencia de artefactos vacíos.

La validación automática **no equivale a una prueba física**.

Las pruebas en hardware real deben registrarse por separado para Android TV, Fire TV, LG, Samsung, Roku y cualquier otra plataforma que se incorpore.

---

## 🗺️ Roadmap

### Fase actual

- [x] Núcleo Flutter independiente.
- [x] Parser M3U con validación.
- [x] Recuperación escalonada.
- [x] Circuit breaker.
- [x] Protección frente a eventos obsoletos.
- [x] Redacción de secretos.
- [x] Pipeline Android.
- [x] Pipeline LG webOS.
- [x] Preparación del pipeline Samsung Tizen.
- [x] Publicación de instaladores mediante GitHub Releases.
- [ ] Sistema completo de releases SemVer automatizadas.
- [ ] Builds de Windows.
- [ ] Builds de Linux.
- [ ] Builds de macOS.
- [ ] Pipeline Roku.
- [ ] Pipeline iPhone/iPad.
- [ ] Pipeline Apple TV/tvOS.
- [ ] Pruebas físicas multiplataforma.

> Los elementos marcados como pendientes no se consideran implementados hasta disponer de un build y una validación reales.

---

## 👨‍💻 Desarrollo

Para desarrollo interno se utiliza Flutter/Dart.

El usuario final **no necesita** estas herramientas para instalar una versión publicada.

Las construcciones oficiales deben realizarse preferentemente mediante GitHub Actions para mantener un proceso reproducible y centralizado.

---

## 📦 Principio de distribución

El repositorio sigue una regla sencilla:

> **Una fuente de código → builds reproducibles → Releases oficiales → descarga por plataforma.**

Esto permite que las futuras mejoras del reproductor puedan publicarse como nuevas versiones sin reemplazar manualmente los instaladores anteriores.

---

## ⚠️ Contenido IPTV

El reproductor es el software de reproducción. El proyecto no debe interpretarse como una distribución de contenido televisivo.

El usuario debe utilizar únicamente listas, streams y servicios para los que tenga autorización o derechos de acceso.

---

## 📄 Licencia

Consulta el archivo [LICENSE](https://github.com/ByD4rking/reproductor-IPTV/blob/main/LICENSE) para conocer las condiciones de uso y distribución del proyecto.

---

## 🔗 Enlaces

- **[Código fuente](https://github.com/ByD4rking/reproductor-IPTV)**
- **[Descargas / Releases](https://github.com/ByD4rking/reproductor-IPTV/releases)**
- **[GitHub Actions](https://github.com/ByD4rking/reproductor-IPTV/actions)**

---

**reproductor-IPTV** — una base multiplataforma preparada para evolucionar, automatizar sus releases y distribuir una versión adecuada para cada dispositivo.
