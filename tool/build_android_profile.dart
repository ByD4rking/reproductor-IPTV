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
  await _configureAndroidReleaseSigning();

  if (profile == 'tv' || profile == 'firetv') {
    await _configureAndroidTv(manifest);
  }

  final buildArgs = <String>['build', 'apk', '--release'];
  final buildNumber = Platform.environment['GITHUB_RUN_NUMBER']?.trim();
  if (buildNumber != null && buildNumber.isNotEmpty) {
    buildArgs.addAll(['--build-number', buildNumber]);
  }
  await _run('flutter', buildArgs);

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

  if (apks.length != 1) {
    throw StateError(
      'Se esperaba exactamente un APK release universal; '
      'se encontraron ${apks.length}.',
    );
  }

  final apk = apks.single;
  final name = apk.uri.pathSegments.last;
  final copiedApk = File('${output.path}/$name');
  await apk.copy(copiedApk.path);
  await _verifyUniversalApk(copiedApk);

  // Se genera un APK universal deliberadamente: el usuario no debe tener que
  // adivinar si su dispositivo necesita arm64, armeabi-v7a o x86_64.
  // Flutter soporta Android API 24+ en esta línea de SDK.
  final hasPersistentSigning = [
    'ANDROID_KEYSTORE_BASE64',
    'ANDROID_KEY_ALIAS',
    'ANDROID_KEY_PASSWORD',
    'ANDROID_STORE_PASSWORD',
  ].every((key) => (Platform.environment[key] ?? '').trim().isNotEmpty);

  final metadata = <String, Object>{
    'profile': profile,
    'platform': 'android',
    'tvOptimized': profile != 'mobile',
    'fireTvCompatible': profile == 'firetv',
    'distribution': 'universal-apk',
    'signing': hasPersistentSigning ? 'persistent-release' : 'debug-fallback',
    'releaseEligible': hasPersistentSigning,
    'minimumAndroidApi': 24,
    'apkFiles': [name],
  };
  await File('${output.path}/profile.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(metadata),
  );

  stdout.writeln('Perfil $profile generado en ${output.path}');
}

Future<void> _verifyUniversalApk(File apk) async {
  final result = await Process.run(
    'unzip',
    ['-l', apk.path],
    runInShell: Platform.isWindows,
  );
  if (result.exitCode != 0) {
    throw StateError('No se pudo inspeccionar el APK universal.');
  }

  final listing = result.stdout.toString();
  const requiredAbis = [
    'lib/armeabi-v7a/libflutter.so',
    'lib/arm64-v8a/libflutter.so',
    'lib/x86_64/libflutter.so',
  ];
  final missing =
      requiredAbis.where((path) => !listing.contains(path)).toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'El APK no es universal: faltan ABIs ${missing.join(', ')}.',
    );
  }
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

Future<void> _configureAndroidReleaseSigning() async {
  final encoded = Platform.environment['ANDROID_KEYSTORE_BASE64']?.trim() ?? '';
  final alias = Platform.environment['ANDROID_KEY_ALIAS']?.trim() ?? '';
  final keyPassword = Platform.environment['ANDROID_KEY_PASSWORD'] ?? '';
  final storePassword = Platform.environment['ANDROID_STORE_PASSWORD'] ?? '';
  final required =
      Platform.environment['REQUIRE_ANDROID_RELEASE_SIGNING'] == 'true';
  final values = [encoded, alias, keyPassword, storePassword];
  if (values.every((value) => value.isEmpty)) {
    if (required) {
      throw StateError(
        'Faltan los secretos de firma Android. Configura ANDROID_KEYSTORE_BASE64, '
        'ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD y ANDROID_STORE_PASSWORD '
        'en GitHub Actions antes de publicar una Release actualizable.',
      );
    }
    stdout.writeln(
      'WARNING: APK de desarrollo con firma temporal; no sirve para garantizar actualizaciones sobre instalaciones previas.',
    );
    return;
  }
  if (values.any((value) => value.isEmpty)) {
    throw StateError('La configuración de firma Android está incompleta.');
  }

  late final List<int> keystoreBytes;
  try {
    keystoreBytes = base64.decode(encoded);
  } on FormatException {
    throw StateError('ANDROID_KEYSTORE_BASE64 no es Base64 válido.');
  }
  if (keystoreBytes.isEmpty) {
    throw StateError('El keystore Android está vacío.');
  }
  final keystore = File(
    '${Directory.systemTemp.path}/reproductor-iptv-release-keystore.jks',
  );
  await keystore.writeAsBytes(keystoreBytes, flush: true);
  final gradleKts = File('android/app/build.gradle.kts');
  final gradleGroovy = File('android/app/build.gradle');
  final gradle = await gradleKts.exists()
      ? gradleKts
      : await gradleGroovy.exists()
          ? gradleGroovy
          : null;
  if (gradle == null) {
    throw StateError('No se encontró el archivo Gradle de Android para configurar la firma.');
  }

  var source = await gradle.readAsString();
  final storePath = keystore.absolute.path.replaceAll('\\\\', '/');
  if (gradle.path.endsWith('.kts')) {
    const debugSigning = 'signingConfig = signingConfigs.getByName("debug")';
    const releaseSigning = 'signingConfig = signingConfigs.getByName("release")';
    if (!source.contains(debugSigning) && !source.contains(releaseSigning)) {
      throw StateError('No se encontró la configuración de firma release esperada en Gradle Kotlin DSL.');
    }
    source = source.replaceAll(debugSigning, releaseSigning);
    const androidAnchor = 'android {';
    if (!source.contains(androidAnchor)) {
      throw StateError('Gradle Kotlin DSL no contiene android {.');
    }
    final signingBlock = '''
    signingConfigs {
        create("release") {
            storeFile = file("$storePath")
            storePassword = System.getenv("ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

''';
    source = source.replaceFirst(androidAnchor, '$androidAnchor\n$signingBlock');
  } else {
    const debugSigning = 'signingConfig signingConfigs.debug';
    const releaseSigning = 'signingConfig signingConfigs.release';
    if (!source.contains(debugSigning) && !source.contains(releaseSigning)) {
      throw StateError('No se encontró la configuración de firma release esperada en Gradle Groovy.');
    }
    source = source.replaceAll(debugSigning, releaseSigning);
    const androidAnchor = 'android {';
    if (!source.contains(androidAnchor)) {
      throw StateError('Gradle Groovy no contiene android {.');
    }
    final signingBlock = '''
    signingConfigs {
        release {
            storeFile file("$storePath")
            storePassword System.getenv("ANDROID_STORE_PASSWORD")
            keyAlias System.getenv("ANDROID_KEY_ALIAS")
            keyPassword System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

''';
    source = source.replaceFirst(androidAnchor, '$androidAnchor\n$signingBlock');
  }
  await gradle.writeAsString(source);
  stdout.writeln('Android Release APK signing configured with the persistent keystore.');
}

Future<void> _ensureInternetPermission(File manifest) async {
  var xml = await manifest.readAsString();
  const permission =
      '    <uses-permission android:name="android.permission.INTERNET" />\n';
  const installPermission =
      '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />\n';
  var applicationIndex = xml.indexOf('<application');
  if (applicationIndex < 0) {
    throw StateError('AndroidManifest no contiene <application>.');
  }

  var changed = false;
  if (!xml.contains('android.permission.REQUEST_INSTALL_PACKAGES')) {
    xml = xml.replaceRange(applicationIndex, applicationIndex, installPermission);
    applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError('AndroidManifest perdió <application> al añadir permiso de instalación.');
    }
    changed = true;
  }

  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceRange(applicationIndex, applicationIndex, permission);
    applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError(
        'AndroidManifest perdió <application> después de insertar INTERNET.',
      );
    }
    changed = true;
  }

  final applicationTagEnd = xml.indexOf('>', applicationIndex);
  if (applicationTagEnd < 0) {
    throw StateError('No se pudo localizar la etiqueta <application>.');
  }
  final existingApplicationTag =
      xml.substring(applicationIndex, applicationTagEnd + 1);
  if (!existingApplicationTag.contains('android:usesCleartextTraffic=')) {
    xml = xml.replaceRange(
      applicationTagEnd,
      applicationTagEnd,
      ' android:usesCleartextTraffic="true"',
    );
    changed = true;
  }

  if (changed) await manifest.writeAsString(xml);

  final verified = await manifest.readAsString();
  if (!verified.contains('android.permission.INTERNET')) {
    throw StateError('La APK release no quedó configurada con INTERNET.');
  }
  if (!verified.contains('android.permission.REQUEST_INSTALL_PACKAGES')) {
    throw StateError('La APK release no quedó configurada para solicitar instalación de actualizaciones.');
  }
  final applicationStart = verified.indexOf('<application');
  final applicationEnd = verified.indexOf('>', applicationStart);
  final applicationTag = applicationStart >= 0 && applicationEnd >= 0
      ? verified.substring(applicationStart, applicationEnd + 1)
      : '';
  if (!applicationTag.contains('android:usesCleartextTraffic="true"')) {
    throw StateError(
      'La APK release no quedó configurada para los streams IPTV HTTP.',
    );
  }
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
        'No se encontró el launcher principal en AndroidManifest.',
      );
    }
    final end = xml.indexOf('/>', launcherIndex);
    if (end < 0) {
      throw StateError('No se pudo modificar el intent-filter principal.');
    }
    const insertion =
        '\n                <category '
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
