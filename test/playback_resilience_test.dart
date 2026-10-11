import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/diagnostics/playback_error.dart';
import 'package:reproductor_iptv/core/playback/monitor/stall_detector.dart';
import 'package:reproductor_iptv/core/playback/monitor/buffer_health_monitor.dart';
import 'package:reproductor_iptv/core/playback/engine/stream_kind.dart';
import 'package:reproductor_iptv/core/playback/engine/playback_engine_state.dart';
import 'package:reproductor_iptv/core/playback/recovery/backoff.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_coordinator.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_policy.dart';
import 'package:reproductor_iptv/core/playback/session/playback_session.dart';
import 'package:reproductor_iptv/core/sources/source_rotation.dart';

void main() {
  test('buffer monitor ignores a brief low-buffer transient', () {
    final monitor = BufferHealthMonitor();
    final start = DateTime(2026, 1, 1);
    final first = monitor.sample(
      bufferedAhead: const Duration(milliseconds: 400),
      playheadMoving: true,
      buffering: true,
      now: start,
    );
    expect(first.degraded, isFalse);

    final transient = monitor.sample(
      bufferedAhead: const Duration(milliseconds: 800),
      playheadMoving: true,
      buffering: true,
      now: start.add(const Duration(seconds: 3)),
    );
    expect(transient.degraded, isFalse);
  });

  test('buffer monitor detects sustained starvation while playback still moves',
      () {
    final monitor = BufferHealthMonitor();
    final start = DateTime(2026, 1, 1);
    monitor.sample(
      bufferedAhead: const Duration(milliseconds: 300),
      playheadMoving: true,
      buffering: true,
      now: start,
    );
    final snapshot = monitor.sample(
      bufferedAhead: const Duration(milliseconds: 250),
      playheadMoving: true,
      buffering: true,
      now: start.add(const Duration(seconds: 6)),
    );
    expect(snapshot.degraded, isTrue);
    expect(snapshot.severe, isTrue);
  });

  test('buffer monitor detects starvation even when engine is not buffering',
      () {
    final monitor = BufferHealthMonitor();
    final start = DateTime(2026, 1, 1);
    monitor.sample(
      bufferedAhead: const Duration(milliseconds: 300),
      playheadMoving: true,
      buffering: false,
      now: start,
    );
    final snapshot = monitor.sample(
      bufferedAhead: const Duration(milliseconds: 200),
      playheadMoving: true,
      buffering: false,
      now: start.add(const Duration(seconds: 6)),
    );
    expect(snapshot.degraded, isTrue);
    expect(snapshot.severe, isTrue);
  });

  test('buffer monitor resets when the buffer recovers', () {
    final monitor = BufferHealthMonitor();
    final start = DateTime(2026, 1, 1);
    monitor.sample(
      bufferedAhead: const Duration(milliseconds: 300),
      playheadMoving: true,
      buffering: true,
      now: start,
    );
    final recovered = monitor.sample(
      bufferedAhead: const Duration(seconds: 4),
      playheadMoving: true,
      buffering: false,
      now: start.add(const Duration(seconds: 3)),
    );
    expect(recovered.degraded, isFalse);
    expect(recovered.lowDuration, Duration.zero);
  });

  test('stall detector ignores healthy incoming data before hard stall', () {
    const detector = StallDetector();
    expect(
      detector.isStalled(
        lastProgressAge: const Duration(seconds: 10),
        buffering: true,
        dataArriving: true,
        playheadMoving: false,
      ),
      isFalse,
    );
    expect(
      detector.isStalled(
        lastProgressAge: const Duration(seconds: 16),
        buffering: true,
        dataArriving: true,
        playheadMoving: false,
      ),
      isTrue,
    );
  });

  test('stall detector exposes hard stall after the recovery deadline', () {
    const detector = StallDetector();
    expect(
      detector.isHardStall(const Duration(seconds: 14)),
      isFalse,
    );
    expect(
      detector.isHardStall(const Duration(seconds: 15)),
      isTrue,
    );
    expect(
      detector.isHardStall(
        const Duration(seconds: 30),
        userPaused: true,
      ),
      isFalse,
    );
  });

  test('stream kind uses MIME when URL has no useful extension', () {
    const detector = StreamKindDetector();
    expect(
      detector.detect(
        Uri.parse('https://example.test/live?id=1'),
        contentType: 'application/vnd.apple.mpegurl',
      ),
      StreamKind.hls,
    );
    expect(
      detector.detect(
        Uri.parse('https://example.test/channel'),
        contentType: 'application/dash+xml',
      ),
      StreamKind.dash,
    );
  });

  test('playback engine state event preserves generation and state', () {
    const event = PlaybackEngineStateEvent(
      generation: 7,
      state: PlaybackEngineState.buffering,
    );
    expect(event.generation, 7);
    expect(event.state, PlaybackEngineState.buffering);
  });

  test('backoff is bounded and deterministic with injected jitter value', () {
    const backoff = ExponentialBackoff();
    expect(backoff.delay(0, randomValue: 0.5), const Duration(seconds: 1));
    expect(
      backoff.delay(10, randomValue: 1.0),
      lessThanOrEqualTo(const Duration(seconds: 8)),
    );
  });

  test('user stop is terminal and never becomes a retry', () {
    const policy = RecoveryPolicy();
    expect(
      policy
          .decide(
            userStopped: true,
            retryable: true,
            retryCount: 0,
            sourceChanges: 0,
          )
          .level,
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

  test('recovery policy escalates retry, reprepare and source switch', () {
    const policy = RecoveryPolicy();
    expect(
      policy
          .decide(
            userStopped: false,
            retryable: true,
            retryCount: 0,
            sourceChanges: 0,
          )
          .level,
      RecoveryLevel.retry,
    );
    expect(
      policy
          .decide(
            userStopped: false,
            retryable: true,
            retryCount: 1,
            sourceChanges: 0,
          )
          .level,
      RecoveryLevel.reprepare,
    );
    expect(
      policy
          .decide(
            userStopped: false,
            retryable: true,
            retryCount: 2,
            sourceChanges: 0,
          )
          .level,
      RecoveryLevel.switchSource,
    );
  });

  test('classifies HTTP auth, missing, transient and timeout failures', () {
    const classifier = PlaybackErrorClassifier();
    expect(classifier.classify(401, null).kind, PlaybackErrorKind.unauthorized);
    expect(classifier.classify(404, null).disposition,
        ErrorDisposition.switchSource);
    expect(classifier.classify(503, null).disposition, ErrorDisposition.retry);
    expect(classifier.classify(null, TimeoutException('timeout')).kind,
        PlaybackErrorKind.timeout);
    expect(classifier.stalled().kind, PlaybackErrorKind.stalled);
  });

  test('classifies runtime player messages conservatively', () {
    const classifier = PlaybackErrorClassifier();
    expect(classifier.classifyMessage('HTTP 404 Not Found').kind,
        PlaybackErrorKind.notFound);
    expect(classifier.classifyMessage('network timeout').kind,
        PlaybackErrorKind.timeout);
    expect(classifier.classifyMessage('decoder codec failure').kind,
        PlaybackErrorKind.decoder);
    expect(classifier.classifyMessage('behind live window').kind,
        PlaybackErrorKind.stalled);
  });

  test('classifies common upstream and unsupported-format runtime failures',
      () {
    const classifier = PlaybackErrorClassifier();
    expect(
      classifier.classifyMessage('HTTP 503 Service Unavailable').disposition,
      ErrorDisposition.retry,
    );
    expect(
      classifier.classifyMessage('connection reset by peer').kind,
      PlaybackErrorKind.network,
    );
    expect(
      classifier.classifyMessage('UnrecognizedInputFormatException').kind,
      PlaybackErrorKind.unsupportedFormat,
    );
  });

  test('recovery coordinator serializes recovery and preserves escalation',
      () async {
    final coordinator = RecoveryCoordinator();
    var reparses = 0;
    var switches = 0;
    final first = await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async => reparses++,
      switchSource: () async => switches++,
    );
    expect(first?.level, RecoveryLevel.retry);
    final second = await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async => reparses++,
      switchSource: () async => switches++,
    );
    expect(second?.level, RecoveryLevel.reprepare);
    final third = await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async => reparses++,
      switchSource: () async => switches++,
    );
    expect(third?.level, RecoveryLevel.switchSource);
    expect(reparses, 2);
    expect(switches, 1);
  });

  test('non-retryable failure switches source before exhausting source budget',
      () async {
    const policy = RecoveryPolicy(maxRetries: 2, maxSourceChanges: 2);
    final first = policy.decide(
      userStopped: false,
      retryable: false,
      retryCount: 0,
      sourceChanges: 0,
    );
    expect(first.level, RecoveryLevel.switchSource);

    final exhausted = policy.decide(
      userStopped: false,
      retryable: false,
      retryCount: 2,
      sourceChanges: 2,
    );
    expect(exhausted.level, RecoveryLevel.failed);
  });

  test('recovery policy can budget switches for every playlist source', () {
    const policy = RecoveryPolicy(maxRetries: 3, maxSourceChanges: 5);
    final decision = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: 3,
      sourceChanges: 4,
    );
    expect(decision.level, RecoveryLevel.switchSource);

    final exhausted = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: 3,
      sourceChanges: 5,
    );
    expect(exhausted.level, RecoveryLevel.degraded);
  });

  test('source rotation advances sequentially without selecting current source', () {
    expect(SourceRotation.nextIndex(currentIndex: 0, sourceCount: 4), 1);
    expect(SourceRotation.nextIndex(currentIndex: 1, sourceCount: 4), 2);
    expect(SourceRotation.nextIndex(currentIndex: 2, sourceCount: 4), 3);
    expect(SourceRotation.nextIndex(currentIndex: 3, sourceCount: 4), 0);
  });

  test('source rotation handles empty and single-source playlists', () {
    expect(SourceRotation.nextIndex(currentIndex: 0, sourceCount: 0), 0);
    expect(SourceRotation.nextIndex(currentIndex: 0, sourceCount: 1), 0);
  });

  test('cancel invalidates a delayed recovery', () async {
    final coordinator = RecoveryCoordinator();
    var called = false;
    final future = coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async => called = true,
      switchSource: () async {},
    );
    coordinator.cancel();
    expect(await future, isNull);
    expect(called, isFalse);
  });

  test('stable playback resets recovery budget', () async {
    final coordinator = RecoveryCoordinator();
    await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async {},
      switchSource: () async {},
    );
    await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async {},
      switchSource: () async {},
    );
    expect(coordinator.retryCount, 2);
    coordinator.resetAfterStablePlayback();
    final result = await coordinator.recover(
      userStopped: false,
      retryable: true,
      reprepare: () async {},
      switchSource: () async {},
    );
    expect(result?.level, RecoveryLevel.retry);
    expect(coordinator.retryCount, 1);
  });
}
