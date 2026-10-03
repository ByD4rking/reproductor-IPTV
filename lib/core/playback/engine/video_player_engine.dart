import 'package:video_player/video_player.dart';

import 'playback_engine.dart';
import 'playback_request.dart';

class VideoPlayerEngine implements PlaybackEngine {
  VideoPlayerController? _controller;

  VideoPlayerController? get controller => _controller;

  @override
  Future<void> prepare(PlaybackRequest request) async {
    final previous = _controller;
    final controller = VideoPlayerController.networkUrl(
      request.source.url,
      httpHeaders: request.effectiveHeaders,
      videoPlayerOptions: const VideoPlayerOptions(mixWithOthers: false),
    );
    _controller = controller;
    await previous?.dispose();
    await controller.initialize();
  }

  @override
  Future<void> play() async => _controller?.play();

  @override
  Future<void> pause() async => _controller?.pause();

  @override
  Future<void> stop() async {
    await _controller?.pause();
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get buffered {
    final values = _controller?.value.buffered ?? const <DurationRange>[];
    if (values.isEmpty) return Duration.zero;
    return values.last.end - position;
  }
}
