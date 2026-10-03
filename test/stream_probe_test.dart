import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reproductor_iptv/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playback/engine/stream_probe.dart';
import 'package:reproductor_iptv/core/playback/engine/stream_kind.dart';

void main() {
  test('rejects unsafe stream URLs before making a request', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('', 200);
    });
    final probe = StreamProbe(client: client);
    addTearDown(probe.dispose);

    final result = await probe.probe(
      StreamSource(
        id: 'unsafe',
        url: Uri.parse('file:///tmp/secret.m3u8'),
      ),
    );

    expect(result, isNull);
    expect(requests, 0);
  });

  test('deeply validates HLS master and child playlist', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
          '/variant.m3u8\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      if (request.url.path == '/variant.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-TARGETDURATION:6\n'
          '#EXTINF:6,\n'
          '/segment.ts\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      if (request.url.path == '/segment.ts') {
        return http.Response.bytes(
          List<int>.filled(128, 7),
          200,
          headers: {'content-type': 'video/mp2t'},
        );
      }
      return http.Response('', 404);
    });

    final probe = StreamProbe(
      client: client,
      timeout: const Duration(seconds: 1),
      maxHlsRequests: 1,
    );
    addTearDown(probe.dispose);

    final result = await probe.probe(
      StreamSource(
        id: 'test',
        url: Uri.parse('https://example.com/master.m3u8'),
      ),
    );

    expect(result, isNotNull);
    expect(result!.kind, StreamKind.hls);
    expect(result.hlsValid, isTrue);
    expect(result.hlsIsMaster, isTrue);
    expect(result.hlsDeepValid, isTrue);
    expect(result.hlsCheckedUriCount, 1);
    expect(result.isAvailable, isTrue);
  });



  test('rejects a valid HLS child playlist when its media segment is dead', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
          '/variant.m3u8\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      if (request.url.path == '/variant.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-TARGETDURATION:6\n'
          '#EXTINF:6,\n'
          '/dead.ts\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      return http.Response('', 404);
    });

    final probe = StreamProbe(
      client: client,
      timeout: const Duration(seconds: 1),
      maxHlsRequests: 1,
    );
    addTearDown(probe.dispose);

    final result = await probe.probe(
      StreamSource(
        id: 'test',
        url: Uri.parse('https://example.com/master.m3u8'),
      ),
    );

    expect(result, isNotNull);
    expect(result!.hlsValid, isTrue);
    expect(result.hlsDeepValid, isFalse);
    expect(result.isAvailable, isFalse);
  });

  test('accepts a master when one rendition is healthy and another is down', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=300000\n'
          '/dead.m3u8\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
          '/live.m3u8\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      if (request.url.path == '/dead.m3u8') {
        return http.Response('', 503);
      }
      if (request.url.path == '/live.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-TARGETDURATION:6\n'
          '#EXTINF:6,\n'
          '/segment.ts\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      if (request.url.path == '/segment.ts') {
        return http.Response.bytes(
          List<int>.filled(64, 7),
          200,
          headers: {'content-type': 'video/mp2t'},
        );
      }
      return http.Response('', 404);
    });

    final probe = StreamProbe(
      client: client,
      timeout: const Duration(seconds: 1),
      maxHlsRequests: 2,
    );
    addTearDown(probe.dispose);

    final result = await probe.probe(
      StreamSource(
        id: 'test',
        url: Uri.parse('https://example.com/master.m3u8'),
      ),
    );

    expect(result, isNotNull);
    expect(result!.hlsIsMaster, isTrue);
    expect(result.hlsCheckedUriCount, 2);
    expect(result.hlsDeepValid, isTrue);
    expect(result.isAvailable, isTrue);
  });

  test('rejects an HLS master whose child playlist is unavailable', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/master.m3u8') {
        return http.Response(
          '#EXTM3U\n'
          '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
          '/missing.m3u8\n',
          200,
          headers: {'content-type': 'application/vnd.apple.mpegurl'},
        );
      }
      return http.Response('', 404);
    });

    final probe = StreamProbe(
      client: client,
      timeout: const Duration(seconds: 1),
      maxHlsRequests: 1,
    );
    addTearDown(probe.dispose);

    final result = await probe.probe(
      StreamSource(
        id: 'test',
        url: Uri.parse('https://example.com/master.m3u8'),
      ),
    );

    expect(result, isNotNull);
    expect(result!.hlsValid, isTrue);
    expect(result.hlsDeepValid, isFalse);
    expect(result.isAvailable, isFalse);
  });
}
