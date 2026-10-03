import '../../domain/entities/stream_source.dart';
import 'circuit_breaker.dart';
import 'source_health_repository.dart';

class SourceHealthManager {
  SourceHealthManager({
    CircuitBreaker breaker = const CircuitBreaker(),
    SourceHealthRepository? repository,
  })  : _breaker = breaker,
        _repository = repository;

  final CircuitBreaker _breaker;
  final SourceHealthRepository? _repository;
  final Map<String, SourceHealth> _health = <String, SourceHealth>{};

  SourceHealth healthOf(String sourceId) =>
      _health[sourceId] ?? SourceHealth.initial();

  bool canAttempt(String sourceId, DateTime now) =>
      _breaker.canAttempt(healthOf(sourceId), now);

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    _health
      ..clear()
      ..addAll(await repository.load());
  }

  Future<bool> beginAttempt(String sourceId, DateTime now) async {
    final current = healthOf(sourceId);
    if (current.state == SourceHealthState.halfOpen) return false;
    final next = _breaker.beginProbe(current, now);
    _health[sourceId] = next;
    if (next.state != current.state ||
        next.cooldownUntil != current.cooldownUntil) {
      await _repository?.save(_health);
    }
    return _breaker.canAttempt(next, now) ||
        next.state == SourceHealthState.halfOpen;
  }

  Future<void> recordSuccess(
    String sourceId,
    DateTime now,
    Duration response,
  ) async {
    _health[sourceId] = _breaker.onSuccess(
      healthOf(sourceId),
      now,
      response,
    );
    await _repository?.save(_health);
  }

  Future<void> recordFailure(String sourceId, DateTime now) async {
    final current = healthOf(sourceId);
    _health[sourceId] = current.state == SourceHealthState.halfOpen
        ? _breaker.probeFailure(current, now)
        : _breaker.onFailure(current, now);
    await _repository?.save(_health);
  }

  Map<String, SourceHealth> snapshot() => Map.unmodifiable(_health);

  void dispose() {
    _repository?.dispose();
  }
}