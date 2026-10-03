class PlaybackEngineError {
  const PlaybackEngineError({
    required this.generation,
    required this.sourceId,
    required this.message,
  });

  final int generation;
  final String sourceId;
  final String message;
}
