import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/domain/entities/playlist.dart';
import '../../core/playback/monitor/stall_detector.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({required this.entry, super.key});
  final PlaylistEntry entry;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _stallDetector = const StallDetector();
  VideoPlayerController? _controller;
  Timer? _healthTimer;
  Duration _lastPosition = Duration.zero;
  DateTime _lastProgress = DateTime.now();
  String _status = 'Preparando';
  String? _error;
  int _sourceIndex = 0;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    _openSource();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkHealth());
  }

  Future<void> _openSource() async {
    if (_recovering) return;
    _recovering = true;
    final source = widget.entry.sources[_sourceIndex];
    final old = _controller;
    final controller = VideoPlayerController.networkUrl(
      source.url,
      httpHeaders: source.headers,
      videoPlayerOptions: const VideoPlayerOptions(mixWithOthers: false),
    );
    _controller = controller;
    await old?.dispose();

    if (mounted) setState(() => _status = 'Conectando fuente ' + (_sourceIndex + 1).toString());

    try {
      await controller.initialize();
      await controller.play();
      _lastPosition = controller.value.position;
      _lastProgress = DateTime.now();
      if (mounted) {
        setState(() {
          _error = null;
          _status = 'Reproduciendo';
        });
      }
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _status = 'Fuente con error');
      await _recover();
    } finally {
      _recovering = false;
    }
  }

  Future<void> _checkHealth() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _recovering) return;

    final position = controller.value.position;
    if (position > _lastPosition) {
      _lastPosition = position;
      _lastProgress = DateTime.now();
      if (mounted && _status != 'Reproduciendo') setState(() => _status = 'Reproduciendo');
      return;
    }

    final age = DateTime.now().difference(_lastProgress);
    final buffering = controller.value.isBuffering;
    final stalled = _stallDetector.isStalled(
      lastProgressAge: age,
      buffering: buffering,
      dataArriving: buffering,
      playheadMoving: false,
    );

    if (mounted && buffering) setState(() => _status = 'Buffering');
    if (stalled) await _recover();
  }

  Future<void> _recover() async {
    if (_recovering || widget.entry.sources.isEmpty) return;
    _recovering = true;
    if (mounted) setState(() => _status = 'Recuperando conexión...');
    final current = _controller;
    await current?.pause();
    await current?.dispose();
    if (widget.entry.sources.length > 1) {
      _sourceIndex = (_sourceIndex + 1) % widget.entry.sources.length;
    }
    _recovering = false;
    await _openSource();
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.channel.displayName),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(_status)),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: ready
            ? AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    if (controller.value.isBuffering)
                      const Center(child: CircularProgressIndicator()),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tv_off, size: 64),
                  const SizedBox(height: 12),
                  Text(_error ?? _status),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _recover,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Recuperar'),
                  ),
                ],
              ),
      ),
      floatingActionButton: ready
          ? FloatingActionButton(
              onPressed: () async {
                if (controller!.value.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
                if (mounted) setState(() {});
              },
              child: Icon(
                controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
