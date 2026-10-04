import '../../domain/entities/playback.dart';

class PlaybackStateMachine {
  PlaybackState _state = PlaybackState.idle;
  String? _sessionId;
  int _generation = 0;
  int _sequence = -1;
  bool _terminal = false;

  PlaybackState get state => _state;

  void start(String sessionId, int generation) {
    _sessionId = sessionId;
    _generation = generation;
    _sequence = -1;
    _terminal = false;
    _state = PlaybackState.preparing;
  }

  bool apply(PlaybackEvent event) {
    if (_terminal ||
        event.sessionId != _sessionId ||
        event.generation != _generation ||
        event.sequence <= _sequence) {
      return false;
    }
    _sequence = event.sequence;
    switch (event.type) {
      case PlaybackEventType.started:
        _state = PlaybackState.playing;
      case PlaybackEventType.buffering:
        _state = PlaybackState.buffering;
      case PlaybackEventType.progressed:
        _state = PlaybackState.playing;
      case PlaybackEventType.stalled:
        _state = PlaybackState.stalled;
      case PlaybackEventType.recovered:
        _state = PlaybackState.playing;
      case PlaybackEventType.failed:
        _state = PlaybackState.failed;
      case PlaybackEventType.sourceChanged:
        _state = PlaybackState.recovering;
      case PlaybackEventType.stopped:
        stop();
    }
    return true;
  }

  void stop() {
    _terminal = true;
    _state = PlaybackState.stopped;
  }
}
