import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final requireNative = args.contains('--require-native');
  final platforms = args.where((arg) => !arg.startsWith('--'))
      .map((arg) => arg.toLowerCase()).toList(growable: false);
  final selected = platforms.isEmpty ? const ['tizen', 'webos'] : platforms;
  var failed = false;

  for (final platform in selected) {
    if (platform != 'tizen' && platform != 'webos') {
      stderr.writeln('Unsupported platform: ' + platform);
      failed = true;
      continue;
    }
    final root = Directory('dist/' + platform + '/package');
    final manifestName = platform == 'tizen' ? 'config.xml' : 'appinfo.json';
    final manifest = File(root.path + '/' + manifestName);
    final index = File(root.path + '/index.html');
    final icon = File(root.path + '/icon.png');
    final checks = <String, bool>{
      'package directory': root.existsSync(),
      'index.html': index.existsSync() && index.lengthSync() > 0,
      'manifest': manifest.existsSync() && manifest.lengthSync() > 0,
      'icon': icon.existsSync() && icon.lengthSync() > 0,
    };
    if (platform == 'webos' && manifest.existsSync()) {
      try {
        final json = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
        checks['webOS manifest type=web'] = json['type'] == 'web';
        checks['webOS main=index.html'] = json['main'] == 'index.html';
      } catch (_) {
        checks['webOS manifest JSON'] = false;
      }
    }
    if (requireNative) {
      final native = Directory('dist/' + platform + '/native');
      final extension = platform == 'tizen' ? '.wgt' : '.ipk';
      final packages = native.existsSync()
          ? native.listSync(recursive: true).whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith(extension)).toList()
          : <File>[];
      checks['native ' + extension] = packages.length == 1;
      if (packages.length == 1) {
        checks['native package non-empty'] = packages.single.lengthSync() > 0;
      }
    }
    for (final entry in checks.entries) {
      stdout.writeln('[' + (entry.value ? 'OK' : 'FAIL') + '] ' + platform + ': ' + entry.key);
      if (!entry.value) failed = true;
    }
  }
  if (failed) exitCode = 1;
}
