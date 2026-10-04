import 'dart:convert';
import 'dart:io';

const _icon80Base64 =
    'iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAABxElEQVR4nO3b0Y2EMAyE4dnTlQD9F0gRe0+WrBV7QAyxJ5m/gmj0WTzxWpblDdXcT/YD2NOAwTRgMA0YTAMG04DBNGCgbds0YGvbtgEAfpPfQZcNZ0nghT7HAyTwVHvDWRJ40H/jARL4taPhLA340dnhLJ2w6+p4gAQCaBvOml5gZDxgYoHR4awpBd41HjCZwDuHs6YR+MR4wAQCnxrOGlrg0+MBgwrsMZw1nMCe4wEDCew9nEU/YNZwFvUJZ48HkAqsMJxFJ7DSeACRwGrDWRQCq44HFBdYeTirrECG8YCCAlmGs0oJZBsPKCKQcTgrXSDzeECiQPbhrO4DjjKc9cr60WaUIdMGtNiHTP+IrOua/YRQ6QJ9jBrTBfoYNZYS6GPRWEqgj0VjWYG+yhrLCvRV1kgh0FdNI4VAXzWNdAJ9FTTSCfRV0Egt0JelcZgBrd5DUp/wXr3PejiBvh4ahxPo66FxaIG+pzQOLdD3lMZpBPru1DiNQN+dGqcU6ItqnFKgL6pxeoG+Fo3TC/S1aJTAL53VqAEPOhpSJ3zQ0VlL4IX2NErghfY0SmBjplECGzONEhhMAoNpwGAaMJgGDKYBg/0Bh7esMp44V60AAAAASUVORK5CYII=';
const _icon130Base64 =
    'iVBORw0KGgoAAAANSUhEUgAAAIIAAACCCAYAAACKAxD9AAAC7ElEQVR4nO3Vy5HbQBAE0VqFTAD9NxBGrC5oLYKiQHAwg+lPPgv6UJH9tSzLt1Der9kHwAeGAEkMARuGAEkMARuGAEkMARuGAEkMARuGAEkMAZLWdWUI1a3rKkn6PfkOTGIDMAyhmOcBGF5DIf8bgUQRSjgagKEIyZ0ZgUQR0jo7AEMREvp0BBJFSKVlAIYiJHFlBBJFCO/qAAxFCKzXCCSKEFLPARiKEMyIEUgUIYxRAzAMwbnRAzC8BsfuGoFEEVy6cwCGIjgzYwQSRXBj1gAMRXBg9ggkijCVhwEYijCJpxFIFOF23gZgKMKNvI5Aogi38DwAQxEGizACiSIME2UAhiF0Fm0AhtfQUdQRSBShi8gDMBThogwjkChCsywDMBShQbYRSBThIxkHYCjCSZlHIFGEt7IPwFCEA1VGIFGElyoNwFCEJxVHIFGEv6oOwJQfQvUBmNKvgRH8KFkEBvCvckVgBK+VKQIDOFaiCIzgvdRFYADnpS0CI/hMuiIwgDapisAI2qUoAgO4LnwRGEEfYYvAAPr6Wpble/YRVzCIPsK/hsfjMfuEFMIXYY86tAtfhD3q0C5VEfaow2dSFWGPOnwmbRH2qMN7aYuwRx3eK1GEPerwWoki7FGH18oVYY86/ChXhD3q8KN0Efaq14EhPKk6iNKv4ZWq74IiHKhUB4pwoFIdKMJJ2etAEU7KXgeK0CBjHShCg4x1oAgXZakDRbgoSx0oQkeR60AROopcB4owSLQ6MITBogyC1zBYlHdBEW7kuQ4U4Uae60ARJvFWB4owibc6UAQHPNSBIjjgoQ4UwZlZdaAIzsyqA0Vw7M46UATH7qwDRQhidB0YQjCjBsFrCGbUu6AIgfWsA0UIrGcdKEISV+tAEZK4WgeKkFBLHShCQi11oAjJna0DRUjubB0oQiFHdaAIhRzVgSIU9VwHhlCcDYLXUJy9C4oASRQBG4YASQwBG4YASQwBG4YASQwBG4YASQwBmz8UyRTPVDWhVAAAAABJRU5ErkJggg==';

Future<void> main(List<String> args) async {
  final targets = _targets(args);
  if (targets.isEmpty) {
    stderr.writeln(
      'Uso: dart run tool/build.dart --target=mobile,tv,firetv,web,tizen,webos',
    );
    exitCode = 64;
    return;
  }
  for (final target in targets) {
    await _buildTarget(target);
  }
}

Set<String> _targets(List<String> args) {
  final result = <String>{};
  for (final arg in args) {
    if (!arg.startsWith('--target=')) continue;
    result.addAll(
      arg
          .substring('--target='.length)
          .split(',')
          .map((v) => v.trim().toLowerCase())
          .where((v) => v.isNotEmpty),
    );
  }
  const supported = {'mobile', 'tv', 'firetv', 'web', 'tizen', 'webos'};
  return result.where(supported.contains).toSet();
}

Future<void> _buildTarget(String target) async {
  switch (target) {
    case 'mobile':
    case 'tv':
    case 'firetv':
      await _run(
        'dart',
        ['run', 'tool/build_android_profile.dart', '--profile=$target'],
      );
      return;
    case 'web':
      await _buildWeb('web');
      return;
    case 'tizen':
      await _buildWebAdapter('tizen');
      return;
    case 'webos':
      throw StateError(
        'webOS no usa Flutter Web. Use flutter-webos build webos --release '
        'con el SDK/NDK oficial de LG.',
      );
  }
}

Future<void> _buildWeb(String profile) async {
  await _run('flutter', ['build', 'web', '--release']);
  await _copyDirectory(
    Directory('build/web'),
    Directory('dist/$profile'),
  );
  await _writeMetadata('dist/$profile/profile.json', <String, Object>{
    'profile': profile,
    'platform': 'web',
    'runtime': 'flutter-web',
    'generatedFrom': 'reproductor_iptv'
  });
}

Future<void> _buildWebAdapter(String platform) async {
  await _run('flutter', ['build', 'web', '--release']);

  final output = Directory('dist/$platform');
  if (await output.exists()) {
    await output.delete(recursive: true);
  }
  await output.create(recursive: true);

  // Copy from build/web directly. Never copy dist/<platform> into package/
  // because package/ would otherwise become part of the recursive source.
  final package = Directory('${output.path}/package');
  await _copyDirectory(Directory('build/web'), package);

  final manifestName = platform == 'tizen' ? 'config.xml' : 'appinfo.json';
  await File('${package.path}/$manifestName').writeAsString(
    await File('platform/$platform/$manifestName').readAsString(),
  );
  await _writeIconPair(package);

  await _writeMetadata(
    '${output.path}/profile.json',
    <String, Object>{
      'profile': platform,
      'platform': platform,
      'runtime': 'flutter-web',
      'renderer': 'canvaskit-full-cpu',
      'packageReady': true,
      'requiresOfficialSdkPackaging': true,
    },
  );

  await File('${output.path}/PLATFORM_ADAPTER.md').writeAsString(
    '# $platform adapter\n\n'
    'Payload Flutter Web generado desde el núcleo único reproductor-IPTV.\n\n'
    'El directorio package/ es autocontenido y usa un arranque webOS compatible; el empaquetado oficial '
    'del fabricante. La firma e instalación requieren el SDK y certificado del '
    'dispositivo objetivo.\n',
  );
}

Future<void> _writeIconPair(Directory package) async {
  await File('${package.path}/icon.png').writeAsBytes(
    base64Decode(_icon80Base64),
  );
  await File('${package.path}/largeicon.png').writeAsBytes(
    base64Decode(_icon130Base64),
  );
}

Future<void> _copyDirectory(
  Directory source,
  Directory destination,
) async {
  if (!await source.exists()) {
    throw StateError('No existe el directorio de build: ${source.path}');
  }
  if (await destination.exists()) {
    await destination.delete(recursive: true);
  }
  await destination.create(recursive: true);
  await for (final entity in source.list(recursive: true)) {
    final relative = entity.path.substring(source.path.length + 1);
    if (entity is Directory) {
      await Directory('${destination.path}/$relative').create(recursive: true);
    } else if (entity is File) {
      final target = File('${destination.path}/$relative');
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
  }
}

Future<void> _writeMetadata(
  String path,
  Map<String, Object> metadata,
) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(metadata),
  );
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final result =
      await Process.run(executable, arguments, runInShell: Platform.isWindows);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'El comando terminó con código ${result.exitCode}.',
      result.exitCode,
    );
  }
}
