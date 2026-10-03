import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/domain/entities/playlist.dart';
import '../../core/playback/engine/playback_request.dart';
import '../../core/playback/engine/video_player_engine.dart';
import '../../core/playback/monitor/stall_detector.dart';
import '../../core/playback/recovery/recovery_policy.dart';
import '../../core/playback/diagnostics/playback_error.dart';
import '../../core/playback/session/playback_session.dart';
import '../../core/playback/source_health/source_health_manager.dart';
import '../../core/history/history_repository.dart';
import '../../core/domain/entities/watch_history.dart';
import '../../core/settings/settings_repository.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({required this.entry, super.key});
  final PlaylistEntry entry;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _engine = VideoPlayerEngine();
  final _session = PlaybackSession('player-session');
  final _stallDetector = const StallDetector();
  final _recoveryPolicy = const RecoveryPolicy();
  final _health = SourceHealthManager(
    repository: SourceHealthRepository(),
  );
  final _history = HistoryRepository();
  final _settingsRepository = SettingsRepository();
  final _errorClassifier = const PlaybackErrorClassifier();
  late final DateTime _startedAt;

  Timer? _healthTimer;
  Duration _lastPosition = Duration.zero;
  DateTime _lastProgress = DateTime.now();
  Duration _lastBufferedAhead = Duration.zero;
  String _status = 'Preparando';
  String? _error;
  int _sourceIndex = 0;
  int _retryCount = 0;
  int _sourceChanges = 0;
  bool _recovering = false;
  bool _autoRecovery = true;
  bool _autoSourceSwitching = true;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _session.start();
    _loadSettingsAndOpen();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkHealth());
  }

  Future<void> _loadSettingsAndOpen() async {
    await _health.load();
    final settings = await _settingsRepository.load();
    if (_session.isStopped) return;
    _autoRecovery = settings.autoRecovery;
    _autoSourceSwitching = settings.autoSourceSwitching;
    await _openSource(automatic: false);
  }

  Future<void> _openSource({required bool automatic, int? operationId}) async {
    if (_session.isStopped || widget.entry.sources.isEmpty) return;
    final operation = operationId ?? _session.beginOperation();
    if (operation < 0) return;

    var attempts = 0;
    while (!_session.isStopped &&
        _session.isCurrentOperation(operation) &&
        attempts < widget.entry.sources.length + 3) {
      final source = widget.entry.sources[_sourceIndex];
      final now = DateTime.now();
      if (!_health.beginAttempt(source.id, now)) {
        _advanceSource();
        attempts++;
        continue;
      }

      if (mounted) setState(() => _status = 'Conectando fuente ${_sourceIndex + 1}');
      final started = DateTime.now();
      try {
        await _engine.prepare(PlaybackRequest(source: source));
        if (!_session.isCurrentOperation(operation) || _session.isStopped) return;
        await _engine.play();
        _health.recordSuccess(source.id, DateTime.now(), DateTime.now().difference(started));
        _retryCount = 0;
        _lastPosition = _engine.position;
        _lastBufferedAhead = _engine.buffered;
        _lastProgress = DateTime.now();
        if (mounted) {
          setState(() {
            _error = null;
            _status = automatic ? 'Fuente recuperada' : 'Reproduciendo';
          });
        }
        return;
      } catch (error) {
        _health.recordFailure(source.id, DateTime.now());
        _error = 'Fuente ${_sourceIndex + 1}: $error';
        attempts++;
        final classified = _errorClassifier.classify(null, error);
        final decision = _recoveryPolicy.decide(
          userStopped: _session.isStopped,
          retryable: classified.disposition == ErrorDisposition.retry,
          retryCount: _retryCount,
          sourceChanges: _sourceChanges,
        );
        if (decision.level == RecoveryLevel.retry ||
            decision.level == RecoveryLevel.reprepare) {
          _retryCount++;
          if (decision.delay > Duration.zero) {
            await Future<void>.delayed(decision.delay);
          }
          continue;
        }
        if (decision.level == RecoveryLevel.switchSource &&
            _autoSourceSwitching &&
            widget.entry.sources.length > 1) {
          _retryCount = 0;
          _sourceChanges++;
          _advanceSource();
          continue;
        }
        break;
      }
    }

    if (mounted && !_session.isStopped) {
      setState(() => _status = 'No hay una fuente reproducible');
    }
  }

  void _advanceSource() {
    if (widget.entry.sources.isEmpty) return;
    _sourceIndex = (_sourceIndex + 1) % widget.entry.sources.length;
  }

  Future<void> _checkHealth() async {
    if (_session.isStopped || _recovering) return;
    final controller = _engine.controller;
    if (controller == null || !controller.value.isInitialized) return;

    final position = _engine.position;
    if (position > _lastPosition) {
      _lastPosition = position;
      _lastProgress = DateTime.now();
      if (mounted && _status != 'Reproduciendo') {
        setState(() => _status = 'Reproduciendo');
      }
      return;
    }

    final age = DateTime.now().difference(_lastProgress);
    final bufferedAhead = _engine.buffered;
    final dataArriving = bufferedAhead > _lastBufferedAhead;
    _lastBufferedAhead = bufferedAhead;
    final buffering = controller.value.isBuffering;
    final stalled = _stallDetector.isStalled(
      lastProgressAge: age,
      buffering: buffering,
      dataArriving: dataArriving,
      playheadMoving: false,
    );

    if (mounted && buffering && !stalled) setState(() => _status = 'Buffering');
    if (stalled && _autoRecovery) await _recover();
  }

  Future<void> _recover() async {
    if (_recovering || _session.isStopped) return;
    _recovering = true;
    final operation = _session.beginOperation();
    if (operation < 0) {
      _recovering = false;
      return;
    }
    if (mounted) setState(() => _status = 'Recuperando conexión...');
    try {
      await _engine.stop();
      final decision = _recoveryPolicy.decide(
        userStopped: false,
        retryable: true,
        retryCount: _retryCount,
        sourceChanges: _sourceChanges,
      );
      if (decision.delay > Duration.zero) {
        await Future<void>.delayed(decision.delay);
      }
      if (!_session.isCurrentOperation(operation)) return;

      if (decision.level == RecoveryLevel.switchSource &&
          _autoSourceSwitching &&
          widget.entry.sources.length > 1) {
        _sourceChanges++;
        _retryCount = 0;
        _advanceSource();
      } else {
        _retryCount++;
      }
      await _openSource(automatic: true, operationId: operation);
    } finally {
      _recovering = false;
    }
  }

  @override
  void dispose() {
    final duration = DateTime.now().difference(_startedAt);
    if (duration > const Duration(seconds: 2)) {
      _history.add(WatchHistoryEntry(
        channelId: widget.entry.channel.id,
        startedAt: _startedAt,
        duration: duration,
        sourceId: widget.entry.sources.isEmpty ? null : widget.entry.sources[_sourceIndex].id,
      ));
    }
    _session.stop();
    _healthTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _engine.controller;
    final ready = controller?.value.isInitialized == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry.channel.displayName),
        actions: [
          IconButton(
            tooltip: 'Recuperar',
            onPressed: _recovering ? null : _recover,
            icon: const Icon(Icons.refresh),
          ),
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
                aspectRatio: controller.value.aspectRatio,
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
                    onPressed: _recovering ? null : _recover,
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
                  await _engine.pause();
                } else {
                  await _engine.play();
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
