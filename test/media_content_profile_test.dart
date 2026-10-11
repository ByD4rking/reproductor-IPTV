import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/domain/entities/media_content_profile.dart';
import 'package:reproductor_iptv/core/playback/engine/hls_playlist_parser.dart';
import 'package:reproductor_iptv/core/playlists/m3u/m3u_parser.dart';

void main() {
  group('media content profile', () {
    test('uses explicit metadata for live, VOD, episode and loop channels', () {
      const parser = M3uParser();
      final cases = <(String, MediaContentType)>[
        ('tvg-type="live"', MediaContentType.live),
        ('media-type="vod"', MediaContentType.vod),
        ('content-type="series-episode"', MediaContentType.seriesEpisode),
        ('stream-type="fast-channel"', MediaContentType.loopChannel),
      ];

      for (final item in cases) {
        final playlist = parser.parse(
          '#EXTM3U\n#EXTINF:-1 ${item.$1},Example\nhttps://cdn.example/test',
        );
        expect(playlist.entries.single.mediaContentProfile.type, item.$2);
        expect(
          playlist.entries.single.mediaContentProfile.confidence,
          MediaContentConfidence.high,
        );
      }
    });

    test('does not infer a loop channel from its name or group title', () {
      const parser = M3uParser();
      final playlist = parser.parse(
        '#EXTM3U\n#EXTINF:-1 group-title="Anime 24/7",Anime Loop\nhttps://cdn.example/stream',
      );
      expect(
        playlist.entries.single.mediaContentProfile.type,
        MediaContentType.unknown,
      );
    });

    test('recognizes standard Xtream URL path patterns conservatively', () {
      final live = MediaContentProfile.fromM3u(
        attributes: const {},
        url: Uri.parse('https://host.example/live/user/pass/12.m3u8'),
      );
      final vod = MediaContentProfile.fromM3u(
        attributes: const {},
        url: Uri.parse('https://host.example/movie/user/pass/12.mp4'),
      );
      final series = MediaContentProfile.fromM3u(
        attributes: const {},
        url: Uri.parse('https://host.example/series/user/pass/12.mkv'),
      );

      expect(live.type, MediaContentType.live);
      expect(vod.type, MediaContentType.vod);
      expect(series.type, MediaContentType.seriesEpisode);
      expect(live.confidence, MediaContentConfidence.medium);
    });
  });

  group('HLS media type evidence', () {
    const parser = HlsPlaylistParser();
    final base = Uri.parse('https://cdn.example/index.m3u8');

    test('classifies a media playlist with ENDLIST as VOD', () {
      final result = parser.parse(
        '#EXTM3U\n#EXTINF:5,one\nseg1.ts\n#EXT-X-ENDLIST',
        base,
      );
      expect(result.isLive, isFalse);
      expect(result.mediaContentProfile.type, MediaContentType.vod);
    });

    test('classifies a media playlist without ENDLIST as live-like', () {
      final result = parser.parse(
        '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,one\nseg1.ts',
        base,
      );
      expect(result.isLive, isTrue);
      expect(result.mediaContentProfile.type, MediaContentType.live);
    });

    test('does not classify a master playlist as live based on ENDLIST absence', () {
      final result = parser.parse(
        '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=100000\nvariant.m3u8',
        base,
      );
      expect(result.isMaster, isTrue);
      expect(result.isLive, isFalse);
      expect(result.mediaContentProfile.type, MediaContentType.unknown);
    });
  });
}
