import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_policy.dart';
import 'package:reproductor_iptv/core/playback/state/playback_state_machine.dart';
import 'package:reproductor_iptv/core/domain/entities/playback.dart';
import 'package:reproductor_iptv/core/playlists/m3u/m3u_parser.dart';
import 'package:reproductor_iptv/core/security/redaction.dart';

void main() {
  test('M3U parser rejects non-http executable schemes', () {
    const text='#EXTM3U\n#EXTINF:-1,Good\nhttps://example.com/live\n#EXTINF:-1,Bad\njavascript:alert(1)';
    final parser = const M3uParser();
    expect(parser.parse(text).entries, hasLength(1));
  });
  test('recovery retries before failover', () {
    const p=RecoveryPolicy();
    expect(p.decide(userStopped:false,retryable:true,retryCount:0,sourceChanges:0).level, RecoveryLevel.retry);
    expect(p.decide(userStopped:false,retryable:true,retryCount:2,sourceChanges:0).level, RecoveryLevel.switchSource);
  });
  test('stop is terminal and stale events are rejected', () {
    final m=PlaybackStateMachine();
    m.start('s',1);
    expect(m.apply(PlaybackEvent(sessionId:'s',generation:1,sequence:1,type:PlaybackEventType.started,at:DateTime.utc(2026))), isTrue);
    expect(m.apply(PlaybackEvent(sessionId:'s',generation:0,sequence:2,type:PlaybackEventType.failed,at:DateTime.utc(2026))), isFalse);
    m.stop();
    expect(m.state, PlaybackState.stopped);
  });
  test('secrets are redacted', () {
    final safe=const SecretRedactor().url(Uri.parse('https://x.test/live?token=abc&channel=1'));
    expect(safe, isNot(contains('abc')));
    expect(safe, contains('[REDACTED]'));
    final headers = const SecretRedactor().headers({'Authorization': 'Bearer abc', 'X-Test': 'ok'});
    expect(headers['Authorization'], '[REDACTED]');
    expect(headers['X-Test'], 'ok');
  });
  test('M3U uses deterministic hash and groups explicit tvg-id sources', () {
    final parser = const M3uParser();
    final first = parser.parse(
      '#EXTM3U\n'
      '#EXTINF:-1 tvg-id="news" group-title="News",News\n'
      'https://example.com/a.m3u8\n'
      '#EXTINF:-1 tvg-id="news" http-user-agent="UA" http-referrer="https://ref.test",News\n'
      'https://example.com/b.m3u8\n',
    );
    final second = parser.parse(
      '#EXTM3U\n'
      '#EXTINF:-1 tvg-id="news" group-title="News",News\n'
      'https://example.com/a.m3u8\n'
      '#EXTINF:-1 tvg-id="news" http-user-agent="UA" http-referrer="https://ref.test",News\n'
      'https://example.com/b.m3u8\n',
    );
    expect(first.rawContentHash, equals(second.rawContentHash));
    expect(first.entries, hasLength(1));
    expect(first.entries.single.sources, hasLength(2));
    expect(first.entries.single.sources[1].headers['Referer'], 'https://ref.test');
  });

  test('M3U accepts single-quoted attributes', () {
    const text = "#EXTM3U\n#EXTINF:-1 tvg-id='abc' group-title='Kids',Kids\nhttps://example.com/live";
    final playlist = const M3uParser().parse(text);
    expect(playlist.entries.single.channel.tvgId, 'abc');
    expect(playlist.entries.single.category, 'Kids');
  });
}
