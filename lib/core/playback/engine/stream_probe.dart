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
    this.hlsDeepValid = false,
    this.hlsCheckedUriCount = 0,
  });

  final StreamKind kind;
  final int statusCode;
  final String? contentType;
  final int bytesRead;
  final bool hlsValid;
  final bool hlsIsMaster;
  final int hlsUriCount;
  final bool hlsDeepValid;
  final int hlsCheckedUriCount;

  bool get isAvailable =>
      statusCode >= 200 &&
          statusCode < 400 &&
          (kind != StreamKind.hls || (hlsValid && hlsDeepValid));
}

class StreamProbe {
  StreamProbe({
    http.Client? client,
    this.timeout = const Duration(seconds: 4),
    this.maxBytes = 64 * 1024,
    this.maxHlsRequests = 2,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final int maxBytes;
  final int maxHlsRequests;

  Future<StreamProbeResult?> probe(
    StreamSource source, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    try {
      final response = await _send(source.url, source, headers);
      final contentType = response.headers['content-type'];
      var kind = const StreamKindDetector().detect(
        source.url,
        contentType: contentType,
      );
      final body = await _readBounded(response.stream, maxBytes);
      final bytesRead = body.length;

      if (kind == StreamKind.unknown || kind == StreamKind.progressive) {
        final text = utf8.decode(body, allowMalformed: true).trimLeft();
        if (text.startsWith('\uFEFF#EXTM3U') ||
            text.startsWith('#EXTM3U') ||
            text.contains('#EXT-X-TARGETDURATION') ||
            text.contains('#EXT-X-STREAM-INF')) {
          kind = StreamKind.hls;
        } else if (text.startsWith('<?xml') && text.contains('<MPD')) {
          kind = StreamKind.dash;
        }
      }

      var hlsValid = false;
      var hlsIsMaster = false;
      var hlsUriCount = 0;
      var hlsDeepValid = true;
      var hlsCheckedUriCount = 0;

      if (kind == StreamKind.hls) {
        final playlist = const HlsPlaylistParser().parse(
          utf8.decode(body, allowMalformed: true),
          source.url,
        );
        hlsValid = playlist.isValid;
        hlsIsMaster = playlist.isMaster;
        hlsUriCount = playlist.uris.length;
        hlsDeepValid = false;

        if (hlsValid && playlist.uris.isNotEmpty) {
          final uris = playlist.uris.take(maxHlsRequests).toList();
          hlsCheckedUriCount = uris.length;
          final checks = await Future.wait(
            uris.map((uri) => _checkHlsChild(uri, source, headers)),
          );
          hlsDeepValid = checks.isNotEmpty && checks.every((value) => value);
        }
      }

      return StreamProbeResult(
        kind: kind,
        statusCode: response.statusCode,
        contentType: contentType,
        bytesRead: bytesRead,
        hlsValid: hlsValid,
        hlsIsMaster: hlsIsMaster,
        hlsUriCount: hlsUriCount,
        hlsDeepValid: hlsDeepValid,
        hlsCheckedUriCount: hlsCheckedUriCount,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _checkHlsChild(
    Uri uri,
    StreamSource source,
    Map<String, String> headers,
  ) async {
    try {
      final response = await _send(uri, source, headers);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return false;
      }
      final body = await _readBounded(response.stream, 8 * 1024);
      if (body.isEmpty) return false;

      final contentType = response.headers['content-type'];
      final looksLikePlaylist =
          uri.path.toLowerCase().endsWith('.m3u8') ||
          (contentType?.toLowerCase().contains('mpegurl') ?? false) ||
          utf8.decode(body, allowMalformed: true).trimLeft().startsWith('#EXTM3U');
      if (!looksLikePlaylist) return true;

      final playlist = const HlsPlaylistParser().parse(
        utf8.decode(body, allowMalformed: true),
        uri,
      );
      return playlist.isValid;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<http.StreamedResponse> _send(
    Uri uri,
    StreamSource source,
    Map<String, String> headers,
  ) {
    final request = http.Request('GET', uri)
      ..headers.addAll(source.headers)
      ..headers.addAll(headers);
    if (source.userAgent != null && source.userAgent!.isNotEmpty) {
      request.headers['User-Agent'] = source.userAgent!;
    }
    return _client.send(request).timeout(timeout);
  }

  static Future<Uint8List> _readBounded(
    Stream<List<int>> stream,
    int limit,
  ) async {
    final body = BytesBuilder(copy: false);
    var bytesRead = 0;
    await for (final chunk in stream.timeout(const Duration(seconds: 4))) {
      if (chunk.isEmpty) continue;
      final remaining = limit - bytesRead;
      if (remaining <= 0) break;
      final sample = chunk.length <= remaining
          ? chunk
          : Uint8List.sublistView(Uint8List.fromList(chunk), 0, remaining);
      body.add(sample);
      bytesRead += sample.length;
      if (bytesRead >= limit) break;
    }
    return body.takeBytes();
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}