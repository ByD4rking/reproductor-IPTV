import 'dart:convert';
import 'dart:io';

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
  await File('${output.path}/PLATFORM_ADAPTER.md').writeAsString(
    '# $platform adapter\n\n'
    'Payload Flutter Web generado desde el núcleo único reproductor-IPTV.\n\n'
    'El empaquetado nativo/launcher debe realizarse con las herramientas oficiales de $platform.\n'
    'La lógica IPTV permanece compartida: M3U, HLS, recuperación, salud de fuentes y catálogo.\n',
  );
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
