class PlaybackEngineError {
  const PlaybackEngineError({
    required this.generation,
    required this.sourceId,
    required this.message,
    this.code,
    this.statusCode,
    this.behindLiveWindow = false,
  });

  final int generation;
  final String sourceId;
  final String message;

  /// Native/player error code when the backend exposes one.
  final String? code;

  /// HTTP status associated with the media request, when known.
  final int? statusCode;

  /// True when a live playback position has fallen outside the live window.
  final bool behindLiveWindow;
}
