import 'dart:io';

Future<void> main(List<String> args) async {
  final profile = _profile(args);
  if (profile == null) {
    stderr.writeln('Uso: dart run tool/build_android_profile.dart --profile=tv|mobile');
    exitCode = 64;
    return;
  }

  await _run('flutter', const ['create', '--platforms=android', '.']);

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!await manifest.exists()) {
    throw StateError('No se encontró el AndroidManifest generado por Flutter.');
  }

  if (profile == 'tv') {
    await _configureAndroidTv(manifest);
  }

  await _run('flutter', const [
    'build',
    'apk',
    '--release',
    '--split-per-abi',
  ]);

  final output = Directory('dist/android/${profile}');
  await output.create(recursive: true);

  final apkDirectory = Directory('build/app/outputs/flutter-apk');
  final apks = apkDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('-release.apk'));

  for (final apk in apks) {
    final name = apk.uri.pathSegments.last;
    await apk.copy('${output.path}/${name}');
  }

  stdout.writeln('Perfil ${profile} generado en ${output.path}');
}

String? _profile(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--profile=')) {
      final value = arg.substring('--profile='.length).trim().toLowerCase();
      if (value == 'tv' || value == 'mobile') return value;
    }
  }
  return null;
}

Future<void> _configureAndroidTv(File manifest) async {
  var xml = await manifest.readAsString();

  const feature =
      '    <uses-feature android:name="android.software.leanback" android:required="false" />\n'
      '    <uses-feature android:name="android.hardware.touchscreen" android:required="false" />\n';

  if (!xml.contains('android.software.leanback')) {
    final applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError('AndroidManifest no contiene <application>.');
    }
    xml = xml.replaceRange(applicationIndex, applicationIndex, feature);
  }

  if (!xml.contains('android.intent.category.LEANBACK_LAUNCHER')) {
    final launcherIndex =
        xml.indexOf('<category android:name="android.intent.category.LAUNCHER"');
    if (launcherIndex < 0) {
      throw StateError('No se encontró el launcher principal en AndroidManifest.');
    }
    final end = xml.indexOf('/>', launcherIndex);
    if (end < 0) {
      throw StateError('No se pudo modificar el intent-filter principal.');
    }
    const insertion =
        '\n                <category android:name="android.intent.category.LEANBACK_LAUNCHER" />';
    xml = xml.replaceRange(end + 2, end + 2, insertion);
  }

  await manifest.writeAsString(xml);
}

Future<void> _run(String executable, List<String> arguments) async {
  stdout.writeln('> $executable ${arguments.join(' ')}');
  final result = await Process.run(
    executable,
    arguments,
    runInShell: Platform.isWindows,
  );
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
