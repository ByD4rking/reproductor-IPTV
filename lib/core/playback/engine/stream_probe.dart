import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/entities/stream_source.dart';
import 'hls_playlist_parser.dart';
import 'stream_kind.dart';

class StreamProbeResult {
  const StreamProbeResult({
    required this.kind,
    required this.statusCode,
    required this.contentType,
    required this.bytesRead,
    this.hlsValid = false,
    this.hlsIsMaster = false,
    this.hlsUriCount = 0,
  });

  final StreamKind kind;
  final int statusCode;
  final String? contentType;
  final int bytesRead;
  final bool hlsValid;
  final bool hlsIsMaster;
  final int hlsUriCount;

  bool get isAvailable =>
      statusCode >= 200 && statusCode < 400 &&
      (kind != StreamKind.hls || hlsValid);
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

  Future<StreamProbeResult?> probe(
    StreamSource source, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final request = http.Request('GET', source.url)
      ..headers.addAll(source.headers)
      ..headers.addAll(headers);
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
      final body = BytesBuilder(copy: false);

      await for (final chunk in response.stream.timeout(timeout)) {
        if (chunk.isEmpty) continue;
        final remaining = maxBytes - bytesRead;
        if (remaining <= 0) break;
        final sample = chunk.length <= remaining
            ? chunk
            : Uint8List.sublistView(Uint8List.fromList(chunk), 0, remaining);
        bytesRead += sample.length;
        body.add(sample);

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

      var hlsValid = false;
      var hlsIsMaster = false;
      var hlsUriCount = 0;
      if (kind == StreamKind.hls) {
        final playlist = const HlsPlaylistParser().parse(
          utf8.decode(body.takeBytes(), allowMalformed: true),
          source.url,
        );
        hlsValid = playlist.isValid;
        hlsIsMaster = playlist.isMaster;
        hlsUriCount = playlist.uris.length;
      }

      return StreamProbeResult(
        kind: kind,
        statusCode: response.statusCode,
        contentType: contentType,
        bytesRead: bytesRead,
        hlsValid: hlsValid,
        hlsIsMaster: hlsIsMaster,
        hlsUriCount: hlsUriCount,
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
