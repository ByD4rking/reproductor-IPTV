# LG webOS — Flutter nativo

El paquete LG no debe generarse con `flutter build web` + `ares-package`. Ese enfoque produce una Web App y no el embedder Flutter nativo para webOS; en TVs donde el navegador no soporta correctamente el renderer Flutter Web puede aparecer el error de que no se creó la superficie de renderizado.

## Ruta soportada

Usamos el Flutter for webOS SDK oficial de LG:

```bash
flutter-webos doctor -v
flutter-webos precache -f
flutter-webos create --platforms webos .
flutter-webos build webos --release
```

El IPK nativo se genera bajo:

```text
build/webos/{arch}/release/ipk/
```

El workflow de Release solo publica este IPK cuando `WEBOS_FLUTTER_ENABLED=true`. Si el toolchain nativo no está configurado, no se publica un IPK webOS falso o basado en Flutter Web.

## Compatibilidad

El SDK oficial de Flutter para webOS actualmente documenta soporte para **webOS TV 26 Re:New y posteriores**. TVs antiguas requieren otra estrategia de cliente webOS y no deben considerarse compatibles automáticamente.

## Reproducción física

Con Developer Mode y Key Server activos:

```bash
flutter-webos devices
flutter-webos run -d <tv> --release
```

La prueba física debe comprobar:
- inicio de la interfaz;
- navegación con Magic Remote/D-pad;
- carga de M3U;
- reproducción HLS;
- cambio de canal;
- EPG;
- recuperación tras corte;
- cierre y reapertura.

## Vídeo

El proyecto incluye la implementación oficial `video_player_webos` para que el motor de reproducción pueda utilizar la integración webOS, en lugar de depender del `video_player` Web del navegador.

## Windows

El SDK oficial se ejecuta en Linux. En Windows se puede usar WSL2 o el DevContainer oficial de LG.
