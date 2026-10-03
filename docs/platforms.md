# Plataforma y generación de builds

El reproductor mantiene un único núcleo Flutter para reproducción, M3U, EPG,
historial, favoritos, salud de fuentes y recuperación. Las variantes de
plataforma deben cambiar solamente la integración y el empaquetado.

## Android

El generador crea APKs desde el mismo proyecto:

```bash
dart run tool/build_android_profile.dart --profile=mobile
dart run tool/build_android_profile.dart --profile=tv
dart run tool/build_android_profile.dart --profile=firetv
```

- `mobile`: APK Android para teléfono/tablet.
- `tv`: Android TV, Google TV y TV Box compatibles con Android.
- `firetv`: perfil Android orientado a Fire TV; comparte el mismo núcleo y
  navegación por control remoto.

Cada ejecución limpia `dist/android/<perfil>`, copia los APK release y genera
`profile.json` con metadatos del artefacto.

## Arquitectura TV

La interfaz debe ser usable con mando a distancia: foco visible, targets
grandes, navegación direccional y activación con Enter/Select. La lógica de
reproducción no debe depender del dispositivo de entrada.

## Próximas plataformas

Samsung Tizen y LG webOS no se tratan como otro APK Flutter. Se prepararán
adaptadores/empaquetadores específicos que consuman el mismo contrato de
reproducción y catálogo, evitando duplicar la lógica de negocio.

## Validación de streams

Para HLS, el probe realiza una validación en cadena limitada:

1. descarga y valida el playlist inicial;
2. resuelve variantes/segmentos;
3. comprueba hasta un número acotado de URIs hijas;
4. limita bytes y tiempo para no convertir el diagnóstico en una descarga;
5. informa al sistema de salud de fuentes antes de considerar disponible el
   stream.

Esto complementa el watchdog de reproducción y el failover de fuentes.
