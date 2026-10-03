import '../../domain/entities/stream_source.dart';
import 'circuit_breaker.dart';

class SourceHealthManager {
  SourceHealthManager({CircuitBreaker breaker = const CircuitBreaker()}) : _breaker = breaker;
  final CircuitBreaker _breaker;
  final Map<String, SourceHealth> _health = <String, SourceHealth>{};

  SourceHealth healthOf(String sourceId) => _health[sourceId] ?? SourceHealth.initial();
  bool canAttempt(String sourceId, DateTime now) => _breaker.canAttempt(healthOf(sourceId), now);

  void recordSuccess(String sourceId, DateTime now, Duration response) {
    _health[sourceId] = _breaker.onSuccess(healthOf(sourceId), now, response);
  }

  void recordFailure(String sourceId, DateTime now) {
    _health[sourceId] = _breaker.onFailure(healthOf(sourceId), now);
  }

  Map<String, SourceHealth> snapshot() => Map.unmodifiable(_health);
}
