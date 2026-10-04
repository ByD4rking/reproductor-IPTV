import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final profile = _profile(args);
  if (profile == null) {
    stderr.writeln(
      'Uso: dart run tool/build_android_profile.dart '
      '--profile=tv|mobile|firetv',
    );
    exitCode = 64;
    return;
  }

  await _run('flutter', const ['create', '--platforms=android', '.']);

  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!await manifest.exists()) {
    throw StateError('No se encontró el AndroidManifest generado por Flutter.');
  }

  await _ensureInternetPermission(manifest);

  if (profile == 'tv' || profile == 'firetv') {
    await _configureAndroidTv(manifest);
  }

  await _run('flutter', const [
    'build',
    'apk',
    '--release',
    '--split-per-abi',
  ]);

  final output = Directory('dist/android/$profile');
  if (await output.exists()) {
    await output.delete(recursive: true);
  }
  await output.create(recursive: true);

  final apkDirectory = Directory('build/app/outputs/flutter-apk');
  if (!await apkDirectory.exists()) {
    throw StateError('Flutter no generó el directorio de APKs esperado.');
  }

  final apks = apkDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('-release.apk'))
      .toList();

  if (apks.isEmpty) {
    throw StateError('No se encontraron APKs release para el perfil $profile.');
  }

  for (final apk in apks) {
    final name = apk.uri.pathSegments.last;
    await apk.copy('${output.path}/$name');
  }

  final metadata = <String, Object>{
    'profile': profile,
    'platform': 'android',
    'tvOptimized': profile != 'mobile',
    'fireTvCompatible': profile == 'firetv',
    'apkFiles': apks.map((file) => file.uri.pathSegments.last).toList(),
  };
  await File('${output.path}/profile.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(metadata),
  );

  stdout.writeln('Perfil $profile generado en ${output.path}');
}

String? _profile(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--profile=')) {
      final value = arg.substring('--profile='.length).trim().toLowerCase();
      if (value == 'tv' || value == 'mobile' || value == 'firetv') {
        return value;
      }
    }
  }
  return null;
}


Future<void> _ensureInternetPermission(File manifest) async {
  var xml = await manifest.readAsString();
  const permission =
      '    <uses-permission android:name="android.permission.INTERNET" />\\n';
  if (xml.contains('android.permission.INTERNET')) return;

  final applicationIndex = xml.indexOf('<application');
  if (applicationIndex < 0) {
    throw StateError('AndroidManifest no contiene <application>.');
  }
  xml = xml.replaceRange(applicationIndex, applicationIndex, permission);
  await manifest.writeAsString(xml);
}

Future<void> _configureAndroidTv(File manifest) async {
  var xml = await manifest.readAsString();

  const feature = '    <uses-feature android:name="android.software.leanback" '
      'android:required="false" />\n'
      '    <uses-feature android:name="android.hardware.touchscreen" '
      'android:required="false" />\n';

  if (!xml.contains('android.software.leanback')) {
    final applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError('AndroidManifest no contiene <application>.');
    }
    xml = xml.replaceRange(applicationIndex, applicationIndex, feature);
  }

  if (!xml.contains('android.intent.category.LEANBACK_LAUNCHER')) {
    final launcherIndex = xml
        .indexOf('<category android:name="android.intent.category.LAUNCHER"');
    if (launcherIndex < 0) {
      throw StateError(
          'No se encontró el launcher principal en AndroidManifest.');
    }
    final end = xml.indexOf('/>', launcherIndex);
    if (end < 0) {
      throw StateError('No se pudo modificar el intent-filter principal.');
    }
    const insertion = '\n                <category '
        'android:name="android.intent.category.LEANBACK_LAUNCHER" />';
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
