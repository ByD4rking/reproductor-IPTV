import 'package:video_player/video_player.dart';
import 'playback_engine.dart';
import 'playback_engine_error.dart';
import 'playback_request.dart';
import 'playback_tracks.dart';
import 'stream_kind.dart';
import 'stream_probe.dart';

class VideoPlayerEngine implements PlaybackEngine {
  VideoPlayerEngine({StreamProbe? probe}) : _probe = probe ?? StreamProbe();

  final StreamProbe _probe;
  final StreamController<PlaybackEngineError> _errors =
      StreamController<PlaybackEngineError>.broadcast();
  VideoPlayerController? _controller;
  int _prepareGeneration = 0;
  String? _activeSourceId;
  String? _lastErrorDescription;

  VideoPlayerController? get controller => _controller;

  @override
  Stream<PlaybackEngineError> get errors => _errors.stream;

  int get generation => _prepareGeneration;
  @override Future<void> prepare(PlaybackRequest request) async {
    final previous = _controller;
    previous?.removeListener(_handleControllerValue);
    final generation = ++_prepareGeneration;
    _activeSourceId = request.source.id;
    _lastErrorDescription = null;
    final formatHint = await _formatHint(request);
    if (generation != _prepareGeneration) return;
    final controller = VideoPlayerController.networkUrl(
      request.source.url,
      formatHint: formatHint,
      httpHeaders: request.effectiveHeaders,
      videoPlayerOptions: const VideoPlayerOptions(mixWithOthers: false),
    );
    controller.addListener(_handleControllerValue);
    try { await controller.initialize(); if (generation != _prepareGeneration) { await controller.dispose(); return; } if (previous != null && identical(_controller, previous)) await previous.dispose(); _controller = controller; } catch (_) { await controller.dispose(); rethrow; }
  }
  @override Future<PlaybackTracks> tracks() async {
    final controller = _controller; if (controller == null || !controller.value.isInitialized) return const PlaybackTracks();
    final video = controller.isVideoTrackSupportAvailable() ? await controller.getVideoTracks() : const <VideoTrack>[];
    final audio = controller.isAudioTrackSupportAvailable() ? await controller.getAudioTracks() : const <VideoAudioTrack>[];
    return PlaybackTracks(video: video.map((track) => PlaybackTrack(id: track.id, label: _videoLabel(track), kind: 'video', selected: track.isSelected, bitrate: track.bitrate, width: track.width, height: track.height, frameRate: track.frameRate, codec: track.codec)).toList(growable: false), audio: audio.map((track) => PlaybackTrack(id: track.id, label: track.label ?? track.language ?? 'Audio', kind: 'audio', language: track.language, selected: track.isSelected, bitrate: track.bitrate, codec: track.codec)).toList(growable: false));
  }
  @override Future<void> selectVideoTrack(String? trackId) async {
    final controller = _controller; if (controller == null || !controller.value.isInitialized || !controller.isVideoTrackSupportAvailable()) return;
    if (trackId == null) { await controller.selectVideoTrack(null); return; }
    final tracks = await controller.getVideoTracks(); for (final track in tracks) { if (track.id == trackId) { await controller.selectVideoTrack(track); return; } }
  }
  @override Future<void> selectAudioTrack(String trackId) async { final controller = _controller; if (controller == null || !controller.value.isInitialized || !controller.isAudioTrackSupportAvailable()) return; await controller.selectAudioTrack(trackId); }
  Future<VideoFormat?> _formatHint(PlaybackRequest request) async {
    final path = request.source.url.path.toLowerCase();
    if (path.endsWith('.m3u8')) return VideoFormat.hls;
    if (path.endsWith('.mpd')) return VideoFormat.dash;
    final result = await _probe.probe(request.source, headers: request.effectiveHeaders);
    switch (result?.kind) {
      case StreamKind.hls: return VideoFormat.hls;
      case StreamKind.dash: return VideoFormat.dash;
      case StreamKind.progressive:
      case StreamKind.unknown:
      case null: return null;
    }
  }

  String _videoLabel(VideoTrack track) {
    if (track.label != null && track.label!.trim().isNotEmpty) return track.label!;
    if (track.height != null) { final bitrate = track.bitrate; final suffix = bitrate == null ? '' : ' · ${(bitrate / 1000000).toStringAsFixed(1)} Mbps'; return '${track.height}p$suffix'; }
    if (track.bitrate != null) return '${(track.bitrate! / 1000).round()} kbps'; return 'Auto';
  }
  @override Future<void> play() async => _controller?.play(); @override Future<void> pause() async => _controller?.pause(); @override Future<void> stop() async => _controller?.pause();
  @override Future<void> dispose() async { _prepareGeneration++; final controller = _controller; _controller = null; await controller?.dispose(); _probe.dispose(); }
  @override Duration get position => _controller?.value.position ?? Duration.zero;
  @override Duration get buffered { final values = _controller?.value.buffered ?? const <DurationRange>[]; if (values.isEmpty) return Duration.zero; final ahead = values.last.end - position; return ahead.isNegative ? Duration.zero : ahead; }
}