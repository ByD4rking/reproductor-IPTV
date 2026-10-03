import 'dart:async';

import 'package:video_player/video_player.dart';

import 'playback_engine.dart';
import 'playback_engine_state.dart';
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
  final StreamController<PlaybackEngineStateEvent> _states =
      StreamController<PlaybackEngineStateEvent>.broadcast();

  VideoPlayerController? _controller;
  int _prepareGeneration = 0;
  String? _activeSourceId;
  String? _lastErrorDescription;

  VideoPlayerController? get controller => _controller;

  @override
  Stream<PlaybackEngineError> get errors => _errors.stream;

  @override
  Stream<PlaybackEngineStateEvent> get states => _states.stream;

  int get generation => _prepareGeneration;

  @override
  Future<void> prepare(PlaybackRequest request) async {
    final previous = _controller;
    previous?.removeListener(_handleControllerValue);

    final generation = ++_prepareGeneration;
    _emitState(PlaybackEngineState.preparing, generation);
    _activeSourceId = request.source.id;
    _lastErrorDescription = null;

    final formatHint = await _formatHint(request);
    if (generation != _prepareGeneration) return;

    final controller = VideoPlayerController.networkUrl(
      request.source.url,
      formatHint: formatHint,
      httpHeaders: request.effectiveHeaders,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    controller.addListener(_handleControllerValue);

    try {
      await controller.initialize();
      if (generation != _prepareGeneration) {
        controller.removeListener(_handleControllerValue);
        controller.dispose();
        return;
      }

      if (previous != null && identical(_controller, previous)) {
        previous.removeListener(_handleControllerValue);
        previous.dispose();
      }
      _controller = controller;
    } catch (_) {
      controller.removeListener(_handleControllerValue);
      controller.dispose();
      rethrow;
    }
  }

  void _handleControllerValue() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isCompleted) {
      _emitState(PlaybackEngineState.completed, _prepareGeneration);
    } else if (controller.value.isBuffering) {
      _emitState(PlaybackEngineState.buffering, _prepareGeneration);
    } else if (controller.value.isPlaying) {
      _emitState(PlaybackEngineState.playing, _prepareGeneration);
    }
    if (!controller.value.hasError) return;

    final description = controller.value.errorDescription;
    if (description == null || description.trim().isEmpty) return;
    if (description == _lastErrorDescription) return;

    _lastErrorDescription = description;
    final sourceId = _activeSourceId;
    if (sourceId == null || _errors.isClosed) return;

    final lower = description.toLowerCase();
    final statusCode = _statusCodeFrom(description);
    _errors.add(
      PlaybackEngineError(
        generation: _prepareGeneration,
        sourceId: sourceId,
        message: description,
        code: lower.contains('decoder')
            ? 'decoder'
            : lower.contains('timeout')
                ? 'timeout'
                : null,
        statusCode: statusCode,
        behindLiveWindow: lower.contains('behind live window') ||
            lower.contains('live window'),
      ),
    );
  }

  int? _statusCodeFrom(String message) {
    final match = RegExp(r'\b(4\d{2}|5\d{2})\b').firstMatch(message);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  Future<PlaybackTracks> tracks() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const PlaybackTracks();
    }
    final video = controller.isVideoTrackSupportAvailable()
        ? await controller.getVideoTracks()
        : const <VideoTrack>[];
    final audio = controller.isAudioTrackSupportAvailable()
        ? await controller.getAudioTracks()
        : const <VideoAudioTrack>[];
    return PlaybackTracks(
      video: video
          .map(
            (track) => PlaybackTrack(
              id: track.id,
              label: _videoLabel(track),
              kind: 'video',
              selected: track.isSelected,
              bitrate: track.bitrate,
              width: track.width,
              height: track.height,
              frameRate: track.frameRate,
              codec: track.codec,
            ),
          )
          .toList(growable: false),
      audio: audio
          .map(
            (track) => PlaybackTrack(
              id: track.id,
              label: track.label ?? track.language ?? 'Audio',
              kind: 'audio',
              language: track.language,
              selected: track.isSelected,
              bitrate: track.bitrate,
              codec: track.codec,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<void> selectVideoTrack(String? trackId) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.isVideoTrackSupportAvailable()) {
      return;
    }
    if (trackId == null) {
      await controller.selectVideoTrack(null);
      return;
    }
    final tracks = await controller.getVideoTracks();
    for (final track in tracks) {
      if (track.id == trackId) {
        await controller.selectVideoTrack(track);
        return;
      }
    }
  }

  @override
  Future<void> selectAudioTrack(String trackId) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.isAudioTrackSupportAvailable()) {
      return;
    }
    await controller.selectAudioTrack(trackId);
  }

  Future<VideoFormat?> _formatHint(PlaybackRequest request) async {
    final path = request.source.url.path.toLowerCase();
    if (path.endsWith('.m3u8')) return VideoFormat.hls;
    if (path.endsWith('.mpd')) return VideoFormat.dash;
    final result = await _probe.probe(
      request.source,
      headers: request.effectiveHeaders,
    );
    switch (result?.kind) {
      case StreamKind.hls:
        return VideoFormat.hls;
      case StreamKind.dash:
        return VideoFormat.dash;
      case StreamKind.progressive:
      case StreamKind.unknown:
      case null:
        return null;
    }
  }

  String _videoLabel(VideoTrack track) {
    if (track.label != null && track.label!.trim().isNotEmpty) {
      return track.label!;
    }
    if (track.height != null) {
      final bitrate = track.bitrate;
      final suffix = bitrate == null
          ? ''
          : ' · ${((bitrate / 1000000).toStringAsFixed(1))} Mbps';
      return '${track.height}p$suffix';
    }
    if (track.bitrate != null) {
      return '${(track.bitrate! / 1000).round()} kbps';
    }
    return 'Auto';
  }

  @override
  Future<void> play() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.play();
    _emitState(PlaybackEngineState.playing, _prepareGeneration);
  }

  @override
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
    _emitState(PlaybackEngineState.paused, _prepareGeneration);
  }

  @override
  Future<void> stop() async {
    _prepareGeneration++;
    _activeSourceId = null;
    _lastErrorDescription = null;
    final controller = _controller;
    if (controller != null) {
      await controller.pause();
    }
    _emitState(PlaybackEngineState.idle, _prepareGeneration);
  }

  @override
  Future<void> dispose() async {
    _prepareGeneration++;
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_handleControllerValue);
    controller?.dispose();
    await _probe.dispose();
    await _errors.close();
    await _states.close();
  }

  void _emitState(PlaybackEngineState state, int generation) {
    if (_states.isClosed) return;
    _states.add(PlaybackEngineStateEvent(generation: generation, state: state));
  }

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get buffered {
    final values = _controller?.value.buffered ?? const <DurationRange>[];
    if (values.isEmpty) return Duration.zero;
    final ahead = values.last.end - position;
    return ahead.isNegative ? Duration.zero : ahead;
  }
}
