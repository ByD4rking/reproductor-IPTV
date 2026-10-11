import 'dart:convert';
import 'dart:io';

const _bufferMarker = 'setBufferDurationsMs(20_000, 60_000, 1_500, 4_000)';

Future<void> main() async {
  final packageConfig = File('.dart_tool/package_config.json');
  if (!await packageConfig.exists()) {
    throw StateError('Falta .dart_tool/package_config.json; ejecuta flutter pub get primero.');
  }

  final decoded = jsonDecode(await packageConfig.readAsString()) as Map<String, dynamic>;
  final packages = decoded['packages'] as List<dynamic>;
  final matches = packages.whereType<Map<String, dynamic>>()
      .where((entry) => entry['name'] == 'video_player_android').toList();
  if (matches.length != 1) {
    throw StateError('Se esperaba una sola dependencia video_player_android; encontradas: ${matches.length}.');
  }

  final rootUri = Uri.parse(matches.single['rootUri'] as String);
  final root = rootUri.isAbsolute ? Directory.fromUri(rootUri) :
      Directory.fromUri(packageConfig.parent.uri.resolveUri(rootUri));
  final files = [
    File('${root.path}/android/src/main/java/io/flutter/plugins/videoplayer/texture/TextureVideoPlayer.java'),
    File('${root.path}/android/src/main/java/io/flutter/plugins/videoplayer/platformview/PlatformViewVideoPlayer.java'),
  ];

  const oldBlock = '''ExoPlayer.Builder builder = new ExoPlayer.Builder(context);
          if (options.backBufferDurationMs != null) {
            if (options.backBufferDurationMs < 0) {
              throw new IllegalArgumentException("backBufferDurationMs must be at least 0");
            }
            if (options.backBufferDurationMs > 0) {
              // Clamp the value to ensure it fits within the int range expected by
              // DefaultLoadControl.
              int backBufferInt =
                  (int) Math.min(options.backBufferDurationMs.longValue(), Integer.MAX_VALUE);
              DefaultLoadControl loadControl =
                  new DefaultLoadControl.Builder()
                      .setBackBuffer(backBufferInt, /* retainBackBufferFromKeyframe= */ true)
                      .build();
              builder.setLoadControl(loadControl);
            }
          }''';

  const newBlock = '''ExoPlayer.Builder builder = new ExoPlayer.Builder(context);
          // Higher forward buffer ceiling for unstable IPTV networks. Keep the
          // byte target at Media3's default to avoid unbounded memory growth.
          DefaultLoadControl.Builder loadControlBuilder =
              new DefaultLoadControl.Builder()
                  .setBufferDurationsMs(20_000, 60_000, 1_500, 4_000);
          if (options.backBufferDurationMs != null) {
            if (options.backBufferDurationMs < 0) {
              throw new IllegalArgumentException("backBufferDurationMs must be at least 0");
            }
            if (options.backBufferDurationMs > 0) {
              int backBufferInt =
                  (int) Math.min(options.backBufferDurationMs.longValue(), Integer.MAX_VALUE);
              loadControlBuilder.setBackBuffer(
                  backBufferInt, /* retainBackBufferFromKeyframe= */ true);
            }
          }
          builder.setLoadControl(loadControlBuilder.build());''';

  for (final file in files) {
    if (!await file.exists()) {
      throw StateError('No se encontró el archivo nativo esperado: ${file.path}');
    }
    final source = await file.readAsString();
    if (source.contains(_bufferMarker)) {
      stdout.writeln('OK: búfer nativo ya configurado en ${file.path}');
      continue;
    }
    if (!source.contains(oldBlock)) {
      throw StateError('El código de ${file.path} no coincide con la versión auditada; se cancela sin aplicar un parche ambiguo.');
    }
    final patched = source.replaceFirst(oldBlock, newBlock);
    if (patched == source || !patched.contains(_bufferMarker)) {
      throw StateError('No se pudo verificar el cambio de búfer en ${file.path}');
    }
    await file.writeAsString(patched);
    final verified = await file.readAsString();
    if (!verified.contains(_bufferMarker) || verified.contains(oldBlock)) {
      throw StateError('Falló la verificación posterior de ${file.path}');
    }
    stdout.writeln('OK: búfer ExoPlayer 20s/60s aplicado y verificado en ${file.path}');
  }
}
