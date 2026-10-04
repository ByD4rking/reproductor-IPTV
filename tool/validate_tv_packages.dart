import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final platforms = args.isEmpty ? const ['tizen', 'webos'] : args;
  var failed = false;

  for (final platform in platforms) {
    if (platform != 'tizen' && platform != 'webos') {
      stderr.writeln('Unsupported platform: $platform');
      failed = true;
      continue;
    }

    final root = Directory('dist/$platform/package');
    final manifest = File(
      '${root.path}/${platform == 'tizen' ? 'config.xml' : 'appinfo.json'}',
    );
    final index = File('${root.path}/index.html');
    final icon = File('${root.path}/icon.png');

    final checks = <String, bool>{
      'package directory': root.existsSync(),
      'index.html': index.existsSync() && index.lengthSync() > 0,
      'manifest': manifest.existsSync() && manifest.lengthSync() > 0,
      'icon': icon.existsSync() && icon.lengthSync() > 0,
    };

    if (platform == 'webos' && manifest.existsSync()) {
      try {
        final json =
            jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
        checks['webOS manifest type=web'] = json['type'] == 'web';
        checks['webOS main=index.html'] = json['main'] == 'index.html';
      } catch (_) {
        checks['webOS manifest JSON'] = false;
      }
    }

    for (final entry in checks.entries) {
      stdout
          .writeln('[${entry.value ? 'OK' : 'FAIL'}] $platform: ${entry.key}');
      if (!entry.value) failed = true;
    }
  }

  if (failed) exitCode = 1;
}
