import 'dart:io';

Future<void> main() async {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!await manifest.exists()) {
    throw StateError(
      'No se encontró AndroidManifest.xml. Ejecuta flutter create --platforms=android . antes.',
    );
  }

  var xml = await manifest.readAsString();
  const permission =
      '    <uses-permission android:name="android.permission.INTERNET" />\n';

  var applicationIndex = xml.indexOf('<application');
  if (applicationIndex < 0) {
    throw StateError('AndroidManifest no contiene <application>.');
  }

  var changed = false;
  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceRange(applicationIndex, applicationIndex, permission);
    applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError('AndroidManifest perdió <application> después de insertar INTERNET.');
    }
    changed = true;
  }

  final applicationTagEnd = xml.indexOf('>', applicationIndex);
  if (applicationTagEnd < 0) {
    throw StateError('No se pudo localizar la etiqueta <application>.');
  }
  final applicationTag = xml.substring(applicationIndex, applicationTagEnd + 1);
  if (!applicationTag.contains('android:usesCleartextTraffic=')) {
    xml = xml.replaceRange(
      applicationTagEnd,
      applicationTagEnd,
      ' android:usesCleartextTraffic="true"',
    );
    changed = true;
  }

  if (changed) {
    await manifest.writeAsString(xml);
    stdout.writeln('Android network permissions/configuration applied.');
  } else {
    stdout.writeln('Android network permissions/configuration already present.');
  }
}
