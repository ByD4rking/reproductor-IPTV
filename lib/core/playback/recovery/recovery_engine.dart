import '../session/playback_session.dart';
import 'recovery_policy.dart';

typedef RecoveryAction = Future<void> Function(RecoveryLevel level);

class RecoveryEngine {
  RecoveryEngine({RecoveryPolicy policy = const RecoveryPolicy()}) : _policy = policy;
  final RecoveryPolicy _policy;
  int _retryCount = 0;
  int _sourceChanges = 0;
  bool _running = false;

  bool get isRunning => _running;
  int get retryCount => _retryCount;
  int get sourceChanges => _sourceChanges;

  Future<RecoveryLevel?> recover({
    required PlaybackSession session,
    required bool retryable,
    required RecoveryAction action,
  }) async {
    if (_running || session.isStopped) return null;
    _running = true;
    try {
      final operation = session.beginOperation();
      if (operation < 0) return RecoveryLevel.stopped;
      final decision = _policy.decide(
        userStopped: session.isStopped,
        retryable: retryable,
        retryCount: _retryCount,
        sourceChanges: _sourceChanges,
      );
      if (decision.level == RecoveryLevel.stopped) return decision.level;
      if (decision.delay > Duration.zero) {
        await Future<void>.delayed(decision.delay);
        if (!session.isCurrentOperation(operation)) return RecoveryLevel.stopped;
      }
      switch (decision.level) {
        case RecoveryLevel.retry:
        case RecoveryLevel.reprepare:
          _retryCount++;
        case RecoveryLevel.switchSource:
          _retryCount = 0;
          _sourceChanges++;
        case RecoveryLevel.wait:
        case RecoveryLevel.degraded:
        case RecoveryLevel.failed:
        case RecoveryLevel.stopped:
          break;
      }
      if (!session.isCurrentOperation(operation)) return RecoveryLevel.stopped;
      await action(decision.level);
      return decision.level;
    } finally {
      _running = false;
    }
  }

  void resetForSource() => _retryCount = 0;
  void reset() {
    _retryCount = 0;
    _sourceChanges = 0;
  }
}
