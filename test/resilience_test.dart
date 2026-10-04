import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/monitor/stall_detector.dart';
import 'package:reproductor_iptv/core/playback/source_health/circuit_breaker.dart';
import 'package:reproductor_iptv/core/playback/source_health/source_health_manager.dart';
import 'package:reproductor_iptv/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playback/diagnostics/playback_error.dart';
import 'package:reproductor_iptv/core/playback/recovery/recovery_policy.dart';
import 'package:reproductor_iptv/core/network/url_policy.dart';

void main() {
  test('brief buffering is not treated as a hard stall', () {
    const d = StallDetector();
    expect(
        d.isStalled(
            lastProgressAge: const Duration(seconds: 2),
            buffering: true,
            dataArriving: false,
            playheadMoving: false),
        isFalse);
    expect(
        d.isStalled(
            lastProgressAge: const Duration(seconds: 6),
            buffering: true,
            dataArriving: false,
            playheadMoving: false),
        isTrue);
  });

  test('moving playhead prevents a false stall even while buffering', () {
    const d = StallDetector();
    expect(
        d.isStalled(
            lastProgressAge: const Duration(seconds: 20),
            buffering: true,
            dataArriving: false,
            playheadMoving: true),
        isFalse);
  });

  test('HTTP auth and not-found errors switch source', () {
    const c = PlaybackErrorClassifier();
    expect(c.classify(401, null).disposition, ErrorDisposition.switchSource);
    expect(c.classify(404, null).disposition, ErrorDisposition.switchSource);
    expect(c.classify(503, null).disposition, ErrorDisposition.retry);
  });

  test('URL policy blocks non-http schemes and excessive redirects', () {
    const p = UrlPolicy();
    expect(p.accepts(Uri.parse('https://example.com')), isTrue);
    expect(p.accepts(Uri.parse('file:///secret')), isFalse);
    expect(p.accepts(Uri.parse('https://user:pass@example.com')), isFalse);
    expect(p.acceptsRedirectCount(6), isFalse);
  });
  test('recovery policy rejects invalid counters', () {
    const policy = RecoveryPolicy();
    final decision = policy.decide(
      userStopped: false,
      retryable: true,
      retryCount: -1,
      sourceChanges: 0,
    );
    expect(decision.level, RecoveryLevel.failed);
  });

  test('circuit breaker permits one half-open probe', () async {
    final breaker = const CircuitBreaker();
    final now = DateTime(2026, 10, 3, 12);
    var health = SourceHealth.initial();
    for (var i = 0; i < 3; i++) {
      health = breaker.onFailure(health, now);
    }
    expect(health.state, SourceHealthState.cooldown);
    expect(breaker.canAttempt(health, now.add(const Duration(seconds: 30))),
        isTrue);

    final probe = breaker.beginProbe(
      health,
      now.add(const Duration(seconds: 30)),
    );
    expect(probe.state, SourceHealthState.halfOpen);
    expect(breaker.canAttempt(probe, now.add(const Duration(seconds: 30))),
        isFalse);
    final manager = SourceHealthManager();
    manager.recordFailure('s1', now);
    manager.recordFailure('s1', now);
    manager.recordFailure('s1', now);
    expect(
        await manager.beginAttempt('s1', now.add(const Duration(seconds: 30))),
        isTrue);
    expect(
        await manager.beginAttempt('s1', now.add(const Duration(seconds: 30))),
        isFalse);

    final recovered = breaker.probeSuccess(
      probe,
      now.add(const Duration(seconds: 31)),
      const Duration(milliseconds: 300),
    );
    expect(recovered.state, SourceHealthState.healthy);
    expect(recovered.consecutiveFailures, 0);
  });

  test('paused and ended playback are never classified as stalls', () {
    const d = StallDetector();
    expect(
      d.isStalled(
        lastProgressAge: const Duration(seconds: 60),
        buffering: true,
        dataArriving: false,
        playheadMoving: false,
        userPaused: true,
      ),
      isFalse,
    );
    expect(
      d.isStalled(
        lastProgressAge: const Duration(seconds: 60),
        buffering: true,
        dataArriving: false,
        playheadMoving: false,
        ended: true,
      ),
      isFalse,
    );
    expect(
      d.isHardStall(
        const Duration(seconds: 60),
        userPaused: true,
      ),
      isFalse,
    );
  });
}
