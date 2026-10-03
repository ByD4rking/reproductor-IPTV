import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_policy.dart';
import 'package:reproductor_iptv/core/playback/state/playback_state_machine.dart';
import 'package:reproductor_iptv/core/domain/entities/playback.dart';
import 'package:reproductor_iptv/core/playlists/m3u/m3u_parser.dart';
import 'package:reproductor_iptv/core/security/redaction.dart';

void main() {
  test('M3U parser rejects non-http executable schemes', () {
    const text='#EXTM3U\n#EXTINF:-1,Good\nhttps://example.com/live\n#EXTINF:-1,Bad\njavascript:alert(1)';
    expect(const M3uParser().parse(text).entries, hasLength(1));
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
}
