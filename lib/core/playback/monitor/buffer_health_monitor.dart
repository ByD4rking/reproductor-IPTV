class BufferHealthSnapshot {
  const BufferHealthSnapshot({
    required this.ahead,
    required this.previousAhead,
    required this.lowDuration,
    required this.degraded,
    required this.severe,
  });

  final Duration ahead;
  final Duration previousAhead;
  final Duration lowDuration;
  final bool degraded;
  final bool severe;
}

class BufferHealthMonitor {
  BufferHealthMonitor({
    this.degradedThreshold = const Duration(seconds: 1),
    this.severeThreshold = const Duration(milliseconds: 500),
    this.degradedAfter = const Duration(seconds: 6),
  });

  final Duration degradedThreshold;
  final Duration severeThreshold;
  final Duration degradedAfter;

  Duration _previousAhead = Duration.zero;
  DateTime? _lowSince;

  BufferHealthSnapshot sample({
    required Duration bufferedAhead,
    required bool playheadMoving,
    required bool buffering,
    required DateTime now,
  }) {
    final previous = _previousAhead;
    final low = bufferedAhead <= degradedThreshold;

    if (!low || (!buffering && bufferedAhead > previous)) {
      _lowSince = null;
    } else {
      _lowSince ??= now;
    }

    final lowDuration = _lowSince == null
        ? Duration.zero
        : now.difference(_lowSince!);
    // Do not depend on the engine's buffering flag. Some HLS/network stalls
    // keep `isBuffering` false while the playhead is still moving briefly.
    // Sustained low buffer is itself a stronger starvation signal.
    final degraded = playheadMoving && lowDuration >= degradedAfter;
    final severe = playheadMoving &&
        bufferedAhead <= severeThreshold &&
        lowDuration >= degradedAfter;

    _previousAhead = bufferedAhead;
    return BufferHealthSnapshot(
      ahead: bufferedAhead,
      previousAhead: previous,
      lowDuration: lowDuration,
      degraded: degraded,
      severe: severe,
    );
  }

  void reset() {
    _previousAhead = Duration.zero;
    _lowSince = null;
  }
}
