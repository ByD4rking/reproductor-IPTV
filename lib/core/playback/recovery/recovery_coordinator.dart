import 'dart:math' as math;

import 'recovery_policy.dart';

class RecoveryCoordinator {
  RecoveryCoordinator({
    RecoveryPolicy policy = const RecoveryPolicy(),
    math.Random? random,
    this.singleSourceRetryDelay = const Duration(seconds: 8),
  })  : _policy = policy,
        _random = random ?? math.Random();

  final RecoveryPolicy _policy;
  final math.Random _random;
  final Duration singleSourceRetryDelay;
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
    bool allowSourceSwitch = true,
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
        randomValue: _random.nextDouble(),
      );

      if (decision.level == RecoveryLevel.switchSource && !allowSourceSwitch) {
        // A channel with one URL cannot switch sources. Previously this
        // branch returned "degraded" without calling reprepare, leaving the
        // player stopped after the retry budget was exhausted. Re-probe the
        // same URL after a cooldown instead of ending the recovery round.
        _retryCount = 0;
        _sourceChanges = 0;
        final fallback = RecoveryDecision(
          level: RecoveryLevel.reprepare,
          delay: singleSourceRetryDelay,
        );
        if (fallback.delay > Duration.zero) {
          await Future<void>.delayed(fallback.delay);
        }
        if (generation != _generation) return null;
        await reprepare();
        return fallback;
      }

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
      // "Degraded" is a state for this recovery round, not a terminal state.
      // Reset the budget so a later health-monitor round can try the source
      // again after a prolonged outage.
      if (decision.level == RecoveryLevel.degraded) {
        _retryCount = 0;
        _sourceChanges = 0;
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
