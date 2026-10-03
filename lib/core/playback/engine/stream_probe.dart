import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/entities/stream_source.dart';
import 'stream_kind.dart';

class StreamProbeResult {
  const StreamProbeResult({
    required this.kind,
    required this.statusCode,
    required this.contentType,
    required this.bytesRead,
  });

  final StreamKind kind;
  final int statusCode;
  final String? contentType;
  final int bytesRead;

  bool get isAvailable => statusCode >= 200 && statusCode < 400;
}

class StreamProbe {
  StreamProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
    this.maxBytes = 64 * 1024,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxBytes;

  Future<StreamProbeResult?> probe(StreamSource source) async {
    final request = http.Request('GET', source.url)
      ..headers.addAll(source.headers);
    if (source.userAgent != null && source.userAgent!.isNotEmpty) {
      request.headers['User-Agent'] = source.userAgent!;
    }

    try {
      final response = await _client.send(request).timeout(timeout);
      final contentType = response.headers['content-type'];
      var kind = const StreamKindDetector().detect(
        source.url,
        contentType: contentType,
      );
      var bytesRead = 0;

      await for (final chunk in response.stream.timeout(timeout)) {
        if (chunk.isEmpty) continue;
        final remaining = maxBytes - bytesRead;
        if (remaining <= 0) break;
        final sample = chunk.length <= remaining
            ? chunk
            : Uint8List.sublistView(Uint8List.fromList(chunk), 0, remaining);
        bytesRead += sample.length;

        if (kind == StreamKind.unknown || kind == StreamKind.progressive) {
          final text = utf8.decode(sample, allowMalformed: true).trimLeft();
          if (text.startsWith('#EXTM3U') ||
              text.contains('#EXT-X-TARGETDURATION') ||
              text.contains('#EXT-X-STREAM-INF')) {
            kind = StreamKind.hls;
          } else if (text.startsWith('<?xml') && text.contains('<MPD')) {
            kind = StreamKind.dash;
          }
        }
        if (bytesRead >= maxBytes) break;
        if (kind != StreamKind.unknown && bytesRead >= 4096) break;
      }

      return StreamProbeResult(
        kind: kind,
        statusCode: response.statusCode,
        contentType: contentType,
        bytesRead: bytesRead,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
