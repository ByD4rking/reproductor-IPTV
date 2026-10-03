enum PlaybackEngineState {
  idle,
  preparing,
  playing,
  buffering,
  paused,
  completed,
  failed,
}

class PlaybackEngineStateEvent {
  const PlaybackEngineStateEvent({
    required this.generation,
    required this.state,
  });

  final int generation;
  final PlaybackEngineState state;
}
