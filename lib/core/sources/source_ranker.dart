import '../domain/entities/stream_source.dart';

class SourceRanker {
  const SourceRanker();
  double score(SourceHealth health) {
    switch (health.state) {
      case SourceHealthState.healthy:
        return 100 - health.consecutiveFailures * 5;
      case SourceHealthState.degraded:
        return 60 - health.consecutiveFailures * 5;
      case SourceHealthState.failing:
        return 20 - health.consecutiveFailures * 2;
      case SourceHealthState.cooldown:
        return -100;
      case SourceHealthState.halfOpen:
        return 40;
    }
  }
}
