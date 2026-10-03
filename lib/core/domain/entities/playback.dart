enum PlaybackState { idle, preparing, playing, buffering, degraded, stalled, recovering, failed, stopped }
enum PlaybackEventType { started, buffering, progressed, stalled, recovered, failed, sourceChanged, stopped }

class PlaybackEvent {
  const PlaybackEvent({required this.sessionId, required this.generation, required this.sequence, required this.type, required this.at, this.position, this.errorCode});
  final String sessionId;
  final int generation;
  final int sequence;
  final PlaybackEventType type;
  final DateTime at;
  final Duration? position;
  final String? errorCode;
}
