import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/domain/entities/playlist.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({required this.entry, super.key});
  final PlaylistEntry entry;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  int _sourceIndex = 0;

  @override
  void initState() {
    super.initState();
    _openSource();
  }

  Future<void> _openSource() async {
    final source = widget.entry.sources[_sourceIndex];
    final old = _controller;
    final controller = VideoPlayerController.networkUrl(source.url, httpHeaders: source.headers);
    _controller = controller;
    await old?.dispose();
    try {
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _error = 'No se pudo reproducir la fuente.');
    }
  }

  Future<void> _retryOrFailover() async {
    if (widget.entry.sources.length > 1) {
      _sourceIndex = (_sourceIndex + 1) % widget.entry.sources.length;
    }
    await _openSource();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller?.value.isInitialized == true;
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.channel.displayName)),
      backgroundColor: Colors.black,
      body: Center(
        child: ready
            ? AspectRatio(aspectRatio: controller!.value.aspectRatio, child: VideoPlayer(controller))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tv_off, size: 64),
                  const SizedBox(height: 12),
                  Text(_error ?? 'Preparando reproducción...'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _retryOrFailover,
                    icon: const Icon(Icons.refresh),
                    label: Text(widget.entry.sources.length > 1 ? 'Reintentar / cambiar fuente' : 'Reintentar'),
                  ),
                ],
              ),
      ),
      floatingActionButton: ready ? FloatingActionButton(
        onPressed: () {
          if (controller!.value.isPlaying) {
            controller.pause();
          } else {
            controller.play();
          }
          setState(() {});
        },
        child: Icon(controller!.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ) : null,
    );
  }
}
