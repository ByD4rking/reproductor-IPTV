class StallDetector {
  const StallDetector({
    this.minStall = const Duration(seconds: 5),
    this.hardStall = const Duration(seconds: 15),
  });

  final Duration minStall;
  final Duration hardStall;

  bool isStalled({
    required Duration lastProgressAge,
    required bool buffering,
    required bool dataArriving,
    required bool playheadMoving,
    bool userPaused = false,
    bool ended = false,
  }) {
    // A stopped/paused/ended player is not a stalled live stream.
    if (userPaused || ended) return false;
    if (playheadMoving) return false;

    // Incoming media data means the pipeline is still alive. Give it the
    // normal stall window before escalating.
    if (dataArriving && lastProgressAge < hardStall) return false;

    // If the player is not buffering but data is arriving, there is no
    // evidence of a transport stall.
    if (!buffering && dataArriving) return false;

    return lastProgressAge >= minStall;
  }

  bool isHardStall(
    Duration lastProgressAge, {
    bool userPaused = false,
    bool ended = false,
  }) {
    if (userPaused || ended) return false;
    return lastProgressAge >= hardStall;
  }
}
