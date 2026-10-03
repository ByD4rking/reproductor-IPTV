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
  const BufferHealthMonitor({
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
    final degraded = playheadMoving &&
        buffering &&
        lowDuration >= degradedAfter;
    final severe = playheadMoving &&
        buffering &&
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
