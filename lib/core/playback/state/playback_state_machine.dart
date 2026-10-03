import '../../domain/entities/playback.dart';

class PlaybackStateMachine {
  PlaybackState _state = PlaybackState.idle;
  String? _sessionId;
  int _generation = 0;
  int _sequence = -1;
  PlaybackState get state => _state;
  void start(String sessionId, int generation) { _sessionId=sessionId; _generation=generation; _sequence=-1; _state=PlaybackState.preparing; }
  bool apply(PlaybackEvent event) {
    if (event.sessionId != _sessionId || event.generation != _generation || event.sequence <= _sequence) return false;
    _sequence=event.sequence;
    switch (event.type) {
      case PlaybackEventType.started: _state=PlaybackState.playing;
      case PlaybackEventType.buffering: if (_state != PlaybackState.stopped) _state=PlaybackState.buffering;
      case PlaybackEventType.progressed: if (_state != PlaybackState.stopped) _state=PlaybackState.playing;
      case PlaybackEventType.stalled: if (_state != PlaybackState.stopped) _state=PlaybackState.stalled;
      case PlaybackEventType.recovered: _state=PlaybackState.playing;
      case PlaybackEventType.failed: _state=PlaybackState.failed;
      case PlaybackEventType.sourceChanged: _state=PlaybackState.recovering;
      case PlaybackEventType.stopped: _state=PlaybackState.stopped;
    }
    return true;
  }
  void stop() => _state=PlaybackState.stopped;
}
