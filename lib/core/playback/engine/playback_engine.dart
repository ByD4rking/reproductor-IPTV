import 'playback_request.dart';
import 'playback_tracks.dart';

abstract interface class PlaybackEngine {
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