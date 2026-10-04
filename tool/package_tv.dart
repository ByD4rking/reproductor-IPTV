import 'dart:io';

Future<void> main(List<String> args) async {
  final targets = _targets(args);
  if (targets.isEmpty) {
    stderr.writeln('Uso: dart run tool/package_tv.dart --target=tizen,webos');
    exitCode = 64;
    return;
  }
  for (final target in targets) {
    if (target == 'webos') {
      await _packageWebOs();
    } else if (target == 'tizen') {
      await _packageTizen();
    }
  }
}

Set<String> _targets(List<String> args) {
  final values = <String>{};
  for (final arg in args) {
    if (!arg.startsWith('--target=')) continue;
    values.addAll(arg
        .substring('--target='.length)
        .split(',')
        .map((v) => v.trim().toLowerCase())
        .where((v) => v.isNotEmpty));
  }
  return values.where({'tizen', 'webos'}.contains).toSet();
}

Future<void> _packageWebOs() async {
  throw StateError(
    'webOS debe empaquetarse exclusivamente con el SDK flutter-webOS de LG. '
    'No se permite convertir dist/webos/package/ en un IPK con ares-package, '
    'porque eso produce una Web App distinta del embedder Flutter nativo. '
    'Use: flutter-webos create --platforms webos . && '
    'flutter-webos build webos --release.',
  );
}

Future<void> _packageTizen() async {
  final cli = _resolveExecutable('tizen', 'TIZEN_CLI');
  final profile = Platform.environment['TIZEN_CERT_PROFILE']?.trim();
  if (profile == null || profile.isEmpty) {
    throw StateError(
        'Falta TIZEN_CERT_PROFILE. Samsung exige un certificado válido para generar un .wgt instalable.');
  }
  final project = Directory('dist/tizen/package');
  _require(project, 'Tizen package payload');
  _require(File('${project.path}/config.xml'), 'Tizen config.xml');
  _require(File('${project.path}/index.html'), 'Tizen index.html');
  final build = Directory('dist/tizen/native-build');
  if (await build.exists()) await build.delete(recursive: true);
  await build.create(recursive: true);
  await _run(cli, ['build-web', '-out', build.path, '--', project.path]);
  final output = Directory('dist/tizen/native');
  if (await output.exists()) await output.delete(recursive: true);
  await output.create(recursive: true);
  await _run(cli, ['package', '-t', 'wgt', '-s', profile, '--', build.path]);
  final produced = _filesWithExtension(build, '.wgt');
  if (produced.length != 1) {
    throw StateError(
        'Tizen debe producir exactamente un .wgt; encontrados: ${produced.length}.');
  }
  final destination =
      File('${output.path}/${produced.single.uri.pathSegments.last}');
  await produced.single.copy(destination.path);
  stdout.writeln('Tizen OK: ${destination.path}');
}

String _resolveExecutable(String fallback, String variable) {
  final configured = Platform.environment[variable]?.trim();
  return configured == null || configured.isEmpty ? fallback : configured;
}

void _require(FileSystemEntity entity, String label) {
  if (!entity.existsSync()) {
    throw StateError('Falta $label: ${entity.path}');
  }
}

List<File> _filesWithExtension(Directory dir, String extension) {
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith(extension))
      .toList();
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final result =
      await Process.run(executable, arguments, runInShell: Platform.isWindows);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(executable, arguments,
        'El comando terminó con código ${result.exitCode}.', result.exitCode);
  }
}
