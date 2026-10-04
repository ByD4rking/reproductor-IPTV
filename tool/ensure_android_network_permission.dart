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

  if (!xml.contains('android.permission.INTERNET')) {
    final applicationIndex = xml.indexOf('<application');
    if (applicationIndex < 0) {
      throw StateError('AndroidManifest no contiene <application>.');
    }
    xml = xml.replaceRange(applicationIndex, applicationIndex, permission);
    await manifest.writeAsString(xml);
    stdout.writeln('Android INTERNET permission added.');
  } else {
    stdout.writeln('Android INTERNET permission already present.');
  }
}
