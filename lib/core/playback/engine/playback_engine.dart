import 'playback_request.dart';

abstract interface class PlaybackEngine {
  Future<void> prepare(PlaybackRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
  Duration get position;
  Duration get buffered;
}
