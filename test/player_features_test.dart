import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/domain/entities/channel.dart';
import 'package:reproductor_iptv/core/domain/entities/catchup.dart';
import 'package:reproductor_iptv/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playback/engine/playback_request.dart';
import 'package:reproductor_iptv/core/playback/monitor/adaptive_buffer_policy.dart';
import 'package:reproductor_iptv/core/playback/monitor/playback_health_signals.dart';
import 'package:reproductor_iptv/core/search/search_index.dart';

void main() {
  test('playback request merges source headers, cookies and user agent', () {
    const source = StreamSource(
      id: 's1',
      url: Uri.parse('https://example.com/live'),
      userAgent: 'source-agent',
      headers: {'X-Source': 'yes'},
    );
    const request = PlaybackRequest(
      source: source,
      userAgent: 'player-agent',
      headers: {'X-Player': 'yes'},
      cookies: {'session': 'abc'},
    );

    expect(request.effectiveHeaders['User-Agent'], 'player-agent');
    expect(request.effectiveHeaders['X-Source'], 'yes');
    expect(request.effectiveHeaders['X-Player'], 'yes');
    expect(request.effectiveHeaders['Cookie'], 'session=abc');
  });

  test('adaptive buffer increases target after instability', () {
    const policy = AdaptiveBufferPolicy();
    const unstable = PlaybackHealthSignals(
      lastProgressAge: Duration(seconds: 6),
      bufferedAhead: Duration(seconds: 1),
      playheadMoving: false,
      dataArriving: true,
      networkActivity: true,
    );

    expect(
      policy.decide(mode: PlaybackMediaMode.live, signals: unstable).targetBuffer,
      const Duration(seconds: 14),
    );
  });

  test('search prioritizes exact and prefix channel matches', () {
    final index = SearchIndex();
    index.addAll(const [
      Channel(id: '1', displayName: 'CNN Chile', tvgId: 'cnn.cl'),
      Channel(id: '2', displayName: 'Chilevisión', tvgId: 'chv.cl'),
      Channel(id: '3', displayName: 'CNN Internacional', tvgId: 'cnn.int'),
    ]);

    final result = index.query('cnn');
    expect(result.first.id, '1');
    expect(result, hasLength(2));
  });

  test('catchup window validates time boundaries', () {
    final window = CatchupWindow(
      start: DateTime.utc(2026, 10, 3, 12),
      end: DateTime.utc(2026, 10, 3, 13),
    );

    expect(window.isValid, isTrue);
    expect(window.contains(DateTime.utc(2026, 10, 3, 12)), isTrue);
    expect(window.contains(DateTime.utc(2026, 10, 3, 13)), isFalse);
  );
}
