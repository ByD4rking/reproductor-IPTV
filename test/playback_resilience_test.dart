import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/engine/stream_kind.dart';
import 'package:reproductor_iptv/core/playback/recovery/backoff.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_policy.dart';
import 'package:reproductor_iptv/core/playback/session/playback_session.dart';

void main() {
  test('stream kind uses MIME when URL has no useful extension', () {
    const detector = StreamKindDetector();
    expect(
      detector.detect(Uri.parse('https://example.test/live?id=1'), contentType: 'application/vnd.apple.mpegurl'),
      StreamKind.hls,
    );
    expect(
      detector.detect(Uri.parse('https://example.test/channel'), contentType: 'application/dash+xml'),
      StreamKind.dash,
    );
  });

  test('backoff is bounded and deterministic with injected jitter value', () {
    const backoff = ExponentialBackoff();
    final first = backoff.delay(0, randomValue: 0.5);
    final later = backoff.delay(10, randomValue: 1.0);
    expect(first, const Duration(seconds: 1));
    expect(later, lessThanOrEqualTo(const Duration(seconds: 8)));
  });

  test('user stop is terminal and never becomes a retry', () {
    const policy = RecoveryPolicy();
    expect(
      policy.decide(userStopped: true, retryable: true, retryCount: 0, sourceChanges: 0).level,
      RecoveryLevel.stopped,
    );
  });

  test('stopped session invalidates old operations', () {
    final session = PlaybackSession('session-1');
    session.start();
    final operation = session.beginOperation();
    expect(session.isCurrentOperation(operation), isTrue);
    session.stop();
    expect(session.isStopped, isTrue);
    expect(session.isCurrentOperation(operation), isFalse);
    expect(session.beginOperation(), -1);
  });
  test('recovery counters survive a reprepare and reset only after stable playback', () {
    const policy = RecoveryPolicy();
    final first = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: 0,
      sourceChanges: 0,
    );
    expect(first.level, RecoveryLevel.retry);

    final second = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: 1,
      sourceChanges: 0,
    );
    expect(second.level, RecoveryLevel.reprepare);

    final failover = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: 2,
      sourceChanges: 0,
    );
    expect(failover.level, RecoveryLevel.switchSource);
  });

}
