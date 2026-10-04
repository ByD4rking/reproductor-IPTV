import 'backoff.dart';

enum RecoveryLevel {
  wait,
  retry,
  reprepare,
  switchSource,
  degraded,
  failed,
  stopped,
}

class RecoveryDecision {
  const RecoveryDecision({required this.level, required this.delay});

  final RecoveryLevel level;
  final Duration delay;
}

class RecoveryPolicy {
  const RecoveryPolicy({
    this.maxRetries = 2,
    this.maxSourceChanges = 2,
    this.backoff = const ExponentialBackoff(),
  });

  final int maxRetries;
  final int maxSourceChanges;
  final ExponentialBackoff backoff;

  RecoveryDecision decide({
    required bool userStopped,
    required bool retryable,
    required int retryCount,
    required int sourceChanges,
    double randomValue = 0.5,
  }) {
    if (userStopped) {
      return const RecoveryDecision(
        level: RecoveryLevel.stopped,
        delay: Duration.zero,
      );
    }

    if (retryCount < 0 || sourceChanges < 0) {
      return const RecoveryDecision(
        level: RecoveryLevel.failed,
        delay: Duration.zero,
      );
    }

    if (!retryable) {
      return sourceChanges < maxSourceChanges
          ? const RecoveryDecision(
              level: RecoveryLevel.switchSource,
              delay: Duration.zero,
            )
          : const RecoveryDecision(
              level: RecoveryLevel.failed,
              delay: Duration.zero,
            );
    }

    if (retryCount < maxRetries) {
      return RecoveryDecision(
        level: retryCount == 0 ? RecoveryLevel.retry : RecoveryLevel.reprepare,
        delay: backoff.delay(retryCount, randomValue: randomValue),
      );
    }

    if (sourceChanges < maxSourceChanges) {
      return const RecoveryDecision(
        level: RecoveryLevel.switchSource,
        delay: Duration.zero,
      );
    }

    return const RecoveryDecision(
      level: RecoveryLevel.degraded,
      delay: Duration.zero,
    );
  }
}
