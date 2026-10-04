import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:reproductor_iptv/core/playback/engine/stream_probe.dart';
import '../lib/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playlists/m3u/m3u_parser.dart';

Future<void> main(List<String> args) async {
  String? url;
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      url = arg;
      break;
    }
  }
  if (url == null) {
    stderr.writeln('Uso: dart run tool/probe_m3u.dart <url-m3u> [--max=100]');
    exitCode = 64;
    return;
  }

  final max = _max(args);
  final client = http.Client();
  final probe = StreamProbe(client: client, timeout: const Duration(seconds: 6), maxHlsRequests: 2);
  try {
    final response = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw StateError('M3U respondió HTTP ${response.statusCode}');
    }
    if (response.body.length > 64 * 1024 * 1024) throw StateError('M3U supera el límite de 64 MiB');

    final playlist = const M3uParser().parse(response.body, playlistId: 'probe', name: url);
    final rows = <Map<String, Object?>>[];
    var tested = 0;
    var available = 0;

    for (final entry in playlist.entries) {
      if (tested >= max) break;
      final source = entry.sources.first;
      final result = await probe.probe(source);
      final ok = result?.isAvailable ?? false;
      if (ok) available++;
      tested++;
      rows.add({
        'channel': entry.channel.displayName,
        'source': source.url.toString(),
        'kind': result?.kind.name,
        'status': result?.statusCode,
        'hlsValid': result?.hlsValid ?? false,
        'hlsDeepValid': result?.hlsDeepValid ?? false,
        'checkedChildren': result?.hlsCheckedUriCount ?? 0,
        'available': ok,
      });
      stdout.writeln('[${ok ? 'OK' : 'FAIL'}] ${entry.channel.displayName}');
    }

    final summary = <String, Object>{
      'playlist': url,
      'channels': playlist.entries.length,
      'tested': tested,
      'available': available,
      'failed': tested - available,
      'availabilityPercent': tested == 0 ? 0 : (available * 100 / tested).round(),
      'results': rows,
    };
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));
  } finally {
    probe.dispose();
    client.close();
  }
}

int _max(List<String> args) {
  for (final arg in args) {
    if (!arg.startsWith('--max=')) continue;
    final value = int.tryParse(arg.substring('--max='.length));
    if (value != null && value > 0) return value;
  }
  return 100;
}
