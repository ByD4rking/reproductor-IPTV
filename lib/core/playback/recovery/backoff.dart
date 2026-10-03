import 'dart:math';

class ExponentialBackoff {
  const ExponentialBackoff({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 8),
    this.jitterRatio = 0.20,
  });

  final Duration base;
  final Duration max;
  final double jitterRatio;

  Duration delay(int attempt, {double randomValue = 0.5}) {
    final exponent = attempt.clamp(0, 30);
    final raw = base.inMilliseconds * pow(2, exponent).toInt();
    final capped = min(raw, max.inMilliseconds);
    final centered = (randomValue.clamp(0.0, 1.0) - 0.5) * 2;
    final jittered = capped * (1 + centered * jitterRatio);
    return Duration(
      milliseconds: max(0, min(max.inMilliseconds, jittered.round())),
    );
  }
}
