import 'recovery_policy.dart';

class RecoveryCoordinator {
  RecoveryCoordinator({RecoveryPolicy policy = const RecoveryPolicy()})
      : _policy = policy;

  final RecoveryPolicy _policy;
  int _retryCount = 0;
  int _sourceChanges = 0;
  bool _running = false;
  int _generation = 0;

  int get retryCount => _retryCount;
  int get sourceChanges => _sourceChanges;
  bool get isRunning => _running;

  void resetAfterStablePlayback() {
    _retryCount = 0;
    _sourceChanges = 0;
  }

  Future<RecoveryDecision?> recover({
    required bool userStopped,
    required bool retryable,
    required Future<void> Function() reprepare,
    required Future<void> Function() switchSource,
  }) async {
    if (_running || userStopped) {
      return userStopped
          ? _policy.decide(
              userStopped: true,
              retryable: retryable,
              retryCount: _retryCount,
              sourceChanges: _sourceChanges,
            )
          : null;
    }

    final generation = ++_generation;
    _running = true;
    try {
      final decision = _policy.decide(
        userStopped: userStopped,
        retryable: retryable,
        retryCount: _retryCount,
        sourceChanges: _sourceChanges,
      );

      if (decision.level == RecoveryLevel.retry ||
          decision.level == RecoveryLevel.reprepare) {
        _retryCount++;
      } else if (decision.level == RecoveryLevel.switchSource) {
        _sourceChanges++;
      }

      if (decision.delay > Duration.zero) {
        await Future<void>.delayed(decision.delay);
      }
      if (generation != _generation) return null;

      switch (decision.level) {
        case RecoveryLevel.retry:
        case RecoveryLevel.reprepare:
          await reprepare();
          break;
        case RecoveryLevel.switchSource:
          await switchSource();
          break;
        case RecoveryLevel.wait:
        case RecoveryLevel.degraded:
        case RecoveryLevel.failed:
        case RecoveryLevel.stopped:
          break;
      }
      return decision;
    } finally {
      if (generation == _generation) {
        _running = false;
      }
    }
  }

  void cancel() {
    _generation++;
    _running = false;
  }
}
