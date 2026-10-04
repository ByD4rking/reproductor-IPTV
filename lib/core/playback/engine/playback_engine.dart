import 'playback_engine_error.dart';
import 'playback_engine_state.dart';
import 'playback_request.dart';
import 'playback_tracks.dart';

abstract interface class PlaybackEngine {
  Stream<PlaybackEngineError> get errors;
  Stream<PlaybackEngineStateEvent> get states;

  Future<void> prepare(PlaybackRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
  Future<PlaybackTracks> tracks();
  Future<void> selectVideoTrack(String? trackId);
  Future<void> selectAudioTrack(String trackId);
  Duration get position;
  Duration get buffered;
}
