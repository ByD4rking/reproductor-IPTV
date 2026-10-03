enum SourceHealthState { healthy, degraded, failing, cooldown, halfOpen }

class StreamSource {
  const StreamSource({
    required this.id,
    required this.url,
    this.userAgent,
    this.headers = const <String, String>{},
  });

  final String id;
  final Uri url;
  final String? userAgent;
  final Map<String, String> headers;
}

class SourceHealth {
  const SourceHealth({
    this.state = SourceHealthState.healthy,
    this.consecutiveFailures = 0,
    this.lastSuccess,
    this.lastFailure,
    this.responseTime,
    this.cooldownUntil,
  });

  final SourceHealthState state;
  final int consecutiveFailures;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final Duration? responseTime;
  final DateTime? cooldownUntil;

  static SourceHealth initial() => const SourceHealth();

  SourceHealth success(DateTime now, Duration response) => SourceHealth(
        state: SourceHealthState.healthy,
        consecutiveFailures: 0,
        lastSuccess: now,
        lastFailure: lastFailure,
        responseTime: response,
        cooldownUntil: null,
      );

  SourceHealth failure(DateTime now) => SourceHealth(
        state: consecutiveFailures + 1 >= 3
            ? SourceHealthState.failing
            : SourceHealthState.degraded,
        consecutiveFailures: consecutiveFailures + 1,
        lastSuccess: lastSuccess,
        lastFailure: now,
        responseTime: responseTime,
        cooldownUntil: cooldownUntil,
      );
}
