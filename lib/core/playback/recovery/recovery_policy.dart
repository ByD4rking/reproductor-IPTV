enum RecoveryLevel { wait, retry, reprepare, switchSource, degraded, failed }
class RecoveryDecision { const RecoveryDecision({required this.level, required this.delay}); final RecoveryLevel level; final Duration delay; }
class RecoveryPolicy {
  const RecoveryPolicy({this.maxRetries=2, this.maxSourceChanges=2, this.baseDelay=const Duration(seconds: 1), this.maxDelay=const Duration(seconds: 8)});
  final int maxRetries;
  final int maxSourceChanges;
  final Duration baseDelay;
  final Duration maxDelay;
  RecoveryDecision decide({required bool userStopped, required bool retryable, required int retryCount, required int sourceChanges}) {
    if (userStopped) return const RecoveryDecision(level: RecoveryLevel.failed, delay: Duration.zero);
    if (!retryable) return const RecoveryDecision(level: RecoveryLevel.switchSource, delay: Duration.zero);
    if (retryCount < maxRetries) {
      final delay = baseDelay * (1 << retryCount);
      return RecoveryDecision(level: retryCount == 0 ? RecoveryLevel.retry : RecoveryLevel.reprepare, delay: delay > maxDelay ? maxDelay : delay);
    }
    if (sourceChanges < maxSourceChanges) return const RecoveryDecision(level: RecoveryLevel.switchSource, delay: Duration.zero);
    return const RecoveryDecision(level: RecoveryLevel.degraded, delay: Duration.zero);
  }
}
