import 'package:flutter_test/flutter_test.dart';

import 'package:reproductor_iptv/core/playback/engine/hls_playlist_parser.dart';

void main() {
  const parser = HlsPlaylistParser();

  test('parses a media playlist and resolves relative segments', () {
    final result = parser.parse(
      '#EXTM3U\n'
      '#EXT-X-TARGETDURATION:6\n'
      '#EXTINF:6,\n'
      'segments/one.ts\n'
      '#EXTINF:6,\n'
      'segments/two.ts\n'
      '#EXT-X-ENDLIST\n',
      Uri.parse('https://example.com/live/channel/index.m3u8'),
    );

    expect(result.isValid, isTrue);
    expect(result.isMaster, isFalse);
    expect(result.isLive, isFalse);
    expect(result.targetDuration, const Duration(seconds: 6));
    expect(
      result.uris,
      <Uri>[
        Uri.parse('https://example.com/live/channel/segments/one.ts'),
        Uri.parse('https://example.com/live/channel/segments/two.ts'),
      ],
    );
  });

  test('parses a master playlist and resolves variants', () {
    final result = parser.parse(
      '#EXTM3U\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=800000\n'
      'low/index.m3u8\n'
      '#EXT-X-STREAM-INF:BANDWIDTH=1800000\n'
      'high/index.m3u8\n',
      Uri.parse('https://example.com/master.m3u8'),
    );

    expect(result.isValid, isTrue);
    expect(result.isMaster, isTrue);
    expect(result.isLive, isTrue);
    expect(result.uris, hasLength(2));
    expect(result.uris.first, Uri.parse('https://example.com/low/index.m3u8'));
    expect(result.uris.last, Uri.parse('https://example.com/high/index.m3u8'));
  });

  test('supports BOM and low-latency HLS parts', () {
    final result = parser.parse(
      '\uFEFF#EXTM3U\n'
      '#EXT-X-TARGETDURATION:2\n'
      '#EXT-X-PART:DURATION=0.5,URI="parts/p1.m4s"\n'
      '#EXT-X-PRELOAD-HINT:TYPE=PART,URI="parts/p2.m4s"\n',
      Uri.parse('https://example.com/live/index.m3u8'),
    );

    expect(result.isValid, isTrue);
    expect(result.isLive, isTrue);
    expect(result.uris, <Uri>[
      Uri.parse('https://example.com/live/parts/p1.m4s'),
      Uri.parse('https://example.com/live/parts/p2.m4s'),
    ]);
  });

  test('rejects non-HLS text', () {
    final result = parser.parse(
      'not a playlist',
      Uri.parse('https://example.com/channel.m3u8'),
    );

    expect(result.isValid, isFalse);
    expect(result.uris, isEmpty);
  });
}