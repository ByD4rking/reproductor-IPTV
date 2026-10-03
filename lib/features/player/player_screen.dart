import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/domain/entities/playlist.dart';
import '../../core/playback/engine/playback_request.dart';
import '../../core/playback/engine/playback_engine_error.dart';
import '../../core/playback/engine/playback_engine_state.dart';
import '../../core/playback/engine/video_player_engine.dart';
import '../../core/playback/monitor/stall_detector.dart';
import '../../core/playback/recovery/recovery_policy.dart';
import '../../core/playback/recovery/recovery_coordinator.dart';
import '../../core/playback/diagnostics/playback_error.dart';
import '../../core/playback/session/playback_session.dart';
import '../../core/playback/source_health/source_health_manager.dart';
import '../../core/playback/source_health/source_health_repository.dart';
import '../../core/history/history_repository.dart';
import '../../core/domain/entities/watch_history.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/platform/tv_focus.dart';

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
  final _recoveryCoordinator = RecoveryCoordinator();
  final _health = SourceHealthManager(
    repository: SourceHealthRepository(),
  );
  final _history = HistoryRepository();
  final _settingsRepository = SettingsRepository();
  final _errorClassifier = const PlaybackErrorClassifier();
  late final DateTime _startedAt;

  Timer? _healthTimer;
  StreamSubscription<PlaybackEngineError>? _playbackErrorSubscription;
  StreamSubscription<PlaybackEngineStateEvent>? _playbackStateSubscription;
  Duration _lastPosition = Duration.zero;
  DateTime _lastProgress = DateTime.now();
  Duration _lastBufferedAhead = Duration.zero;
  String _status = 'Preparando';
  String? _error;
  int _sourceIndex = 0;
    DateTime? _stablePlaybackSince;
  bool _recovering = false;
  bool _autoRecovery = true;
  bool _autoSourceSwitching = true;
  DateTime? _sourceAttemptStarted;
  bool _healthCheckRunning = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _session.start();
    _playbackErrorSubscription = _engine.errors.listen(_handleEngineError);
    _playbackStateSubscription = _engine.states.listen(_handleEngineState);
    _loadSettingsAndOpen();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkHealth());
  }

  void _handleEngineState(PlaybackEngineStateEvent event) {
    if (_session.isStopped || event.generation != _engine.generation) return;
    final status = switch (event.state) {
      PlaybackEngineState.idle => 'Detenido',
      PlaybackEngineState.preparing => 'Preparando',
      PlaybackEngineState.playing => 'Reproduciendo',
      PlaybackEngineState.buffering => 'Buffering',
      PlaybackEngineState.paused => 'Pausado',
      PlaybackEngineState.completed => 'Finalizado',
      PlaybackEngineState.failed => 'Error de reproducción',
    };
    if (mounted && _status != status) {
      setState(() => _status = status);
    }
  }

  Future<void> _handleEngineError(PlaybackEngineError event) async {
    if (_session.isStopped || _recovering) return;
    if (event.generation != _engine.generation) return;
    if (widget.entry.sources.isEmpty ||
        widget.entry.sources[_sourceIndex].id != event.sourceId) {
      return;
    }

    final classified = event.behindLiveWindow
        ? _errorClassifier.stalled()
        : event.statusCode != null
            ? _errorClassifier.classify(event.statusCode, null)
            : _errorClassifier.classifyMessage(event.message);
    _error = classified.message;
    if (mounted) {
      setState(() => _status = 'Error de reproducción: ${classified.kind.name}');
    }
    if (!_autoRecovery) return;

    await _recover(
      retryable: classified.disposition == ErrorDisposition.retry,
      markFailure: true,
    );
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
      if (!await _health.beginAttempt(source.id, now)) {
        _advanceSource();
        attempts++;
        continue;
      }

      if (mounted) setState(() => _status = 'Conectando fuente ${_sourceIndex + 1}');
      final started = DateTime.now();
      _sourceAttemptStarted = started;
      try {
        await _engine.prepare(PlaybackRequest(source: source));
        if (!_session.isCurrentOperation(operation) || _session.isStopped) return;
        await _engine.play();
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
        await _health.recordFailure(source.id, DateTime.now());
        _error = 'Fuente ${_sourceIndex + 1}: $error';
        attempts++;
        final classified = _errorClassifier.classify(null, error);
        final decision = await _recoveryCoordinator.recover(
          userStopped: _session.isStopped,
          retryable: classified.disposition == ErrorDisposition.retry,
          reprepare: () async {
            if (_session.isCurrentOperation(operation)) {
              await _engine.stop();
              await _engine.prepare(PlaybackRequest(source: source));
              await _engine.play();
            }
          },
          allowSourceSwitch:
              _autoSourceSwitching && widget.entry.sources.length > 1,
          switchSource: () async {
            if (_autoSourceSwitching && widget.entry.sources.length > 1) {
              _advanceSource();
              final next = widget.entry.sources[_sourceIndex];
              await _engine.prepare(PlaybackRequest(source: next));
              await _engine.play();
            }
          },
        );
        if (decision == null || decision.level == RecoveryLevel.degraded) {
          break;
        }
        if (decision.level == RecoveryLevel.failed ||
            decision.level == RecoveryLevel.stopped) {
          break;
        }
        if (decision.level == RecoveryLevel.retry ||
            decision.level == RecoveryLevel.reprepare ||
            decision.level == RecoveryLevel.switchSource) {
          if (_session.isCurrentOperation(operation)) continue;
          break;
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
    _lastPosition = Duration.zero;
    _lastBufferedAhead = Duration.zero;
    _lastProgress = DateTime.now();
    _stablePlaybackSince = null;
    _sourceAttemptStarted = null;
  }

  Future<void> _checkHealth() async {
    if (_session.isStopped || _recovering || _healthCheckRunning) return;
    final controller = _engine.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!controller.value.isPlaying) return;

    _healthCheckRunning = true;
    try {
      final position = _engine.position;
      final playheadMoving = position > _lastPosition;
      final progressAt = DateTime.now();

      if (playheadMoving) {
        _lastPosition = position;
        _lastProgress = progressAt;
        _stablePlaybackSince ??= progressAt;
        if (_stablePlaybackSince != null &&
            progressAt.difference(_stablePlaybackSince!) >= const Duration(seconds: 15)) {
          _recoveryCoordinator.resetAfterStablePlayback();
          _stablePlaybackSince = progressAt;
        }
        final source = widget.entry.sources.isEmpty ? null : widget.entry.sources[_sourceIndex];
        final started = _sourceAttemptStarted;
        if (source != null && started != null) {
          await _health.recordSuccess(
            source.id,
            progressAt,
            progressAt.difference(started),
          );
          _sourceAttemptStarted = null;
        }
        if (mounted && _status != 'Reproduciendo') {
          setState(() => _status = 'Reproduciendo');
        }
        return;
      }

      final age = progressAt.difference(_lastProgress);
      final bufferedAhead = _engine.buffered;
      final dataArriving = bufferedAhead > _lastBufferedAhead;
      _lastBufferedAhead = bufferedAhead;
      final buffering = controller.value.isBuffering;
      final ended = controller.value.isCompleted;
      if (ended) {
        if (mounted && _status != 'Finalizado') {
          setState(() => _status = 'Finalizado');
        }
        return;
      }

      final stalled = _stallDetector.isStalled(
        lastProgressAge: age,
        buffering: buffering,
        dataArriving: dataArriving,
        playheadMoving: playheadMoving,
        ended: ended,
      );

      if (mounted && buffering && !stalled) setState(() => _status = 'Buffering');
      if (stalled && _autoRecovery) {
        await _recover(markFailure: true);
      }
    } finally {
      _healthCheckRunning = false;
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _engine.controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await _engine.pause();
    } else {
      await _engine.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _recover({bool retryable = true, bool markFailure = false}) async {
    if (_recovering || _session.isStopped) return;
    final source = widget.entry.sources.isEmpty ? null : widget.entry.sources[_sourceIndex];
    if (markFailure && source != null) {
      await _health.recordFailure(source.id, DateTime.now());
      _sourceAttemptStarted = null;
    }

    _recovering = true;
    _stablePlaybackSince = null;
    final operation = _session.beginOperation();
    if (operation < 0) {
      _recovering = false;
      return;
    }
    if (mounted) setState(() => _status = 'Recuperando conexión...');

    try {
      await _engine.stop();
      final decision = await _recoveryCoordinator.recover(
        userStopped: _session.isStopped,
        retryable: retryable,
        reprepare: () async {
          if (_session.isCurrentOperation(operation)) {
            await _openSource(automatic: true, operationId: operation);
          }
        },
        allowSourceSwitch: _autoSourceSwitching && widget.entry.sources.length > 1,
        switchSource: () async {
          if (!_autoSourceSwitching || widget.entry.sources.length <= 1) {
            return;
          }
          if (_session.isCurrentOperation(operation)) {
            _advanceSource();
            await _openSource(automatic: true, operationId: operation);
          }
        },
      );

      if (decision?.level == RecoveryLevel.degraded && mounted) {
        setState(() => _status = 'Reproducción degradada');
      }
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
    _recoveryCoordinator.cancel();
    _playbackErrorSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _healthTimer?.cancel();
    _health.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _engine.controller;
    if (controller == null || !controller.value.isInitialized) {
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
          child: Column(
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
      );
    }

    final activeController = controller;
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
      body: Focus(
        autofocus: true,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                  event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.space)) {
            unawaited(_togglePlayback());
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Center(
          child: AspectRatio(
          aspectRatio: activeController.value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
              VideoPlayer(activeController),
                if (activeController.value.isBuffering)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: TvFocusable(
        onActivate: () => unawaited(_togglePlayback()),
        child: FloatingActionButton(
          onPressed: null,
          child: Icon(
          activeController.value.isPlaying
              ? Icons.pause
              : Icons.play_arrow,
          ),
        ),
      ),
    );
  }
}
