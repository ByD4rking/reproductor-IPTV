import 'dart:convert';
import 'dart:io';

const _icon80Base64 = 'iVBORw0KGgoAAAANSUhEUgAAAFAAAABQCAYAAACOEfKtAAAA3klEQVR42u3b2w2AIBAEQDvw0x7svz/twQjsHWOyDUzwwR4e53U/8j0HBIAAAQIUgAABAhSAAAEClKWAFS4r0C0MUAACBAhQAAIECBBg1/y9790KcERxsAXgyOalPeDo6qot4KzuryXgzPK0HeDs9rkN4Kr6vgXgyvlHacCEAVJZwJQJXEnApBFmKcDEGXAZwNQhejxg+ikEK9AzEKC3sO9AOxF7YYDaGH2gRhqgmYipnLmwkwkAnY1xOgsgCIAAAQIUgAABAvTLvxXoFgYIUAACBAhQAAIECFAAAgzOCzuBv0oZ88FFAAAAAElFTkSuQmCC';
const _icon130Base64 = 'iVBORw0KGgoAAAANSUhEUgAAAIIAAACCCAYAAACKAxD9AAABPUlEQVR42u3csQ3AIAwAQW9AyQ7Zfz+noKNFEQQf0i+ATq7A0fqTUrgEgSAQBIJAEAgCQSAIBIEgEASCQBAIAkEgCASBIBAEgkAQCKoFwRnHRJCJIBAEgkAQCAJBIAgEgSAQBIJAEAgCQSAIBIEELT4HA8ECECAIEEAIEGAAAQAQIAABAhAAAAECECAAAQAQIAABABAgAAECEAAAAQIQAAABAhAgACEAACEchAqL9QEoZ+x3RUEIECAAQQgQIABBBhAAAIEGEAAAgQYQIABBCBAgAEE+ekkfx/lN7TsR5CNKbJDSR+DAAEGEIAAQRMGEASC/hMIAkEgCASBIBAEgkAQCAJBIAgEgSAQBIJA0HUQnDOespkIAkEgCASBIBAEgkAQCAJBIAgEgSAQBIJAEAgCQSAIBIEgEASCNvQCYLjDoUyMm2YAAAAASUVORK5CYII=';

Future<void> main(List<String> args) async {
  final targets = _targets(args);
  if (targets.isEmpty) {
    stderr.writeln('Uso: dart run tool/build.dart --target=mobile,tv,firetv,web,tizen,webos');
    exitCode = 64;
    return;
  }
  for (final target in targets) { await _buildTarget(target); }
}

Set<String> _targets(List<String> args) {
  final result = <String>{};
  for (final arg in args) {
    if (!arg.startsWith('--target=')) continue;
    result.addAll(arg.substring('--target='.length).split(',').map((v) => v.trim().toLowerCase()).where((v) => v.isNotEmpty));
  }
  const supported = {'mobile','tv','firetv','web','tizen','webos'};
  return result.where(supported.contains).toSet();
}

Future<void> _buildTarget(String target) async {
  switch (target) {
    case 'mobile':
    case 'tv':
    case 'firetv':
      await _run('dart', ['run', 'tool/build_android_profile.dart', '--profile=$target']);
      return;
    case 'web':
      await _buildWeb('web');
      return;
    case 'tizen':
      await _buildWebAdapter('tizen');
      return;
    case 'webos':
      await _buildWebAdapter('webos');
      return;
  }
}

Future<void> _buildWeb(String profile) async {
  await _run('flutter', ['build', 'web', '--release']);
  await _copyDirectory(Directory('build/web'), Directory('dist/$profile'));
  await _writeMetadata('dist/$profile/profile.json', <String, Object>{'profile': profile, 'platform': 'web', 'runtime': 'flutter-web', 'generatedFrom': 'reproductor_iptv'});
}

Future<void> _buildWebAdapter(String platform) async {
  await _buildWeb(platform);
  final output = Directory('dist/$platform');
  final package = Directory('${output.path}/package');
  if (await package.exists()) await package.delete(recursive: true);
  await _copyDirectory(output, package);
  await File('${package.path}/${platform == 'tizen' ? 'config.xml' : 'appinfo.json'}').writeAsString(
    await File('platform/$platform/${platform == 'tizen' ? 'config.xml' : 'appinfo.json'}').readAsString(),
  );
  await _writeIconPair(package);
  await File('${output.path}/PLATFORM_ADAPTER.md').writeAsString(
    '# $platform adapter\n\n'
    'Payload Flutter Web generado desde el núcleo único reproductor-IPTV.\n\n'
    'El directorio package/ es autocontenido y queda listo para la herramienta oficial de empaquetado de $platform.\n'
    'La lógica IPTV permanece compartida: M3U, HLS, recuperación, salud de fuentes y catálogo.\n',
  );
}

Future<void> _writeIconPair(Directory package) async {
  await File('${package.path}/icon.png').writeAsBytes(base64Decode(_icon80Base64));
  await File('${package.path}/largeicon.png').writeAsBytes(base64Decode(_icon130Base64));
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  if (!await source.exists()) throw StateError('No existe el directorio de build: ${source.path}');
  if (await destination.exists()) await destination.delete(recursive: true);
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

Future<void> _writeMetadata(String path, Map<String, Object> metadata) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final result = await Process.run(executable, arguments, runInShell: Platform.isWindows);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) throw ProcessException(executable, arguments, 'El comando terminó con código ${result.exitCode}.', result.exitCode);
}
