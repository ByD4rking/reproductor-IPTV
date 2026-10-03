import '../../domain/entities/stream_source.dart';

abstract interface class PlaybackEngine {
  Future<void> prepare(StreamSource source);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
  Duration get position;
  Duration get buffered;
}
