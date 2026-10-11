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
    Duration? degradedThreshold,
    Duration? degradedAfter,
  }) {
    final previous = _previousAhead;
    final effectiveThreshold = degradedThreshold ?? this.degradedThreshold;
    final effectiveAfter = degradedAfter ?? this.degradedAfter;
    final low = bufferedAhead <= effectiveThreshold;

    if (!low) {
      _lowSince = null;
    } else {
      _lowSince ??= now;
    }

    final lowDuration =
        _lowSince == null ? Duration.zero : now.difference(_lowSince!);
    // A low buffer while the playhead is still advancing is a warning, not
    // sufficient evidence to restart playback. Live streams can legitimately
    // maintain a small buffer, and restarting them creates avoidable cutouts.
    // Escalate to severe only when the native player also reports buffering.
    final degraded = playheadMoving && lowDuration >= effectiveAfter;
    final severe = buffering &&
        bufferedAhead <= severeThreshold &&
        lowDuration >= effectiveAfter;

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
