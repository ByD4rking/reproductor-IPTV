import '../../domain/entities/stream_source.dart';

class CircuitBreaker {
  const CircuitBreaker({this.failureThreshold = 3, this.cooldown = const Duration(seconds: 30)});

  final int failureThreshold;
  final Duration cooldown;

  SourceHealth onFailure(SourceHealth current, DateTime now) {
    final failures = current.consecutiveFailures + 1;
    if (failures >= failureThreshold) {
      return SourceHealth(
        state: SourceHealthState.cooldown,
        consecutiveFailures: failures,
        lastSuccess: current.lastSuccess,
        lastFailure: now,
        responseTime: current.responseTime,
        cooldownUntil: now.add(cooldown),
      );
    }
    return current.failure(now);
  }

  SourceHealth onSuccess(SourceHealth current, DateTime now, Duration response) => current.success(now, response);

  bool canAttempt(SourceHealth health, DateTime now) {
    final until = health.cooldownUntil;
    if (health.state != SourceHealthState.cooldown) return true;
    return until == null || !now.isBefore(until);
  }

  SourceHealth beginProbe(SourceHealth health, DateTime now) {
    if (!canAttempt(health, now) || health.state != SourceHealthState.cooldown) return health;
    return SourceHealth(
      state: SourceHealthState.halfOpen,
      consecutiveFailures: health.consecutiveFailures,
      lastSuccess: health.lastSuccess,
      lastFailure: health.lastFailure,
      responseTime: health.responseTime,
      cooldownUntil: null,
    );
  }
}
