import '../domain/entities/stream_source.dart';

class SourceRanker {
  const SourceRanker();

  double score(SourceHealth health) {
    final latencyPenalty = _latencyPenalty(health.responseTime);
    final successBonus = health.lastSuccess == null ? 0 : 4;

    switch (health.state) {
      case SourceHealthState.healthy:
        return 100 + successBonus - latencyPenalty;
      case SourceHealthState.degraded:
        return 60 + successBonus - health.consecutiveFailures * 5 -
            latencyPenalty;
      case SourceHealthState.failing:
        return 20 - health.consecutiveFailures * 2 - latencyPenalty;
      case SourceHealthState.cooldown:
        return -100;
      case SourceHealthState.halfOpen:
        return 40 - latencyPenalty;
    }
  }

  double _latencyPenalty(Duration? response) {
    if (response == null) return 0;
    final milliseconds = response.inMilliseconds;
    if (milliseconds <= 1000) return 0;
    return ((milliseconds - 1000) / 1000).clamp(0, 30).toDouble();
  }
}
