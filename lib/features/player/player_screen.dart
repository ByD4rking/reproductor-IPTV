import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/domain/entities/playlist.dart';
import '../../core/domain/entities/stream_source.dart';
import '../../core/playback/engine/playback_engine_error.dart';
import '../../core/playback/engine/playback_request.dart';
import '../../core/playback/engine/playback_engine_state.dart';
import '../../core/playback/diagnostics/playback_error.dart';
import '../../core/playback/engine/video_player_engine.dart';
import '../../core/playback/monitor/stall_detector.dart';
import '../../core/playback/monitor/buffer_health_monitor.dart';
import '../../core/playback/recovery/recovery_coordinator.dart';
import '../../core/playback/recovery/recovery_policy.dart';
import '../../core/playback/session/playback_session.dart';
import '../../core/playback/source_health/source_health_manager.dart';
import '../../core/playback/source_health/source_health_repository.dart';
import '../../core/history/history_repository.dart';
import '../../core/domain/entities/watch_history.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/platform/tv_focus.dart';
import '../../core/sources/source_ranker.dart';

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
  final _bufferHealthMonitor = BufferHealthMonitor();
  final _recoveryCoordinator = RecoveryCoordinator();
  final _health = SourceHealthManager(
    repository: SourceHealthRepository(),
  );
  final _history = HistoryRepository();
  final _settingsRepository = SettingsRepository();
  final _errorClassifier = const PlaybackErrorClassifier();
  final _sourceRanker = const SourceRanker();
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
  bool _userPaused = false;
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _session.start();
    _playbackErrorSubscription = _engine.errors.listen(_handleEngineError);
    _playbackStateSubscription = _engine.states.listen(_handleEngineState);
    _loadSettingsAndOpen();
    _healthTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkHealth());
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
      setState(
          () => _status = 'Error de reproducción: ${classified.kind.name}');
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
    _sourceIndex = _bestSourceIndex();
    await _openSource(automatic: false);
  }

  Future<void> _openSource({
    required bool automatic,
    int? operationId,
    bool allowNestedRecovery = true,
  }) async {
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

      if (mounted) {
        setState(() => _status = 'Conectando fuente ${_sourceIndex + 1}');
      }
      final started = DateTime.now();
      _sourceAttemptStarted = started;
      try {
        await _engine.prepare(PlaybackRequest(source: source));
        if (!_session.isCurrentOperation(operation) || _session.isStopped) {
          return;
        }
        await _engine.play();
        _userPaused = false;
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
        if (!allowNestedRecovery) {
          break;
        }

        final decision = await _recoveryCoordinator.recover(
          userStopped: _session.isStopped,
          retryable: classified.disposition == ErrorDisposition.retry,
          reprepare: () async {
            if (_session.isCurrentOperation(operation)) {
              await _openSource(
                automatic: true,
                operationId: operation,
                allowNestedRecovery: false,
              );
            }
          },
          allowSourceSwitch:
              _autoSourceSwitching && widget.entry.sources.length > 1,
          switchSource: () async {
            if (_autoSourceSwitching && widget.entry.sources.length > 1) {
              // Only select the next source here. The main loop performs the
              // tracked beginAttempt/prepare/play sequence so source health
              // and circuit-breaker state cannot be bypassed.
              _advanceSource();
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
          if (_session.isCurrentOperation(operation)) {
            _lastPosition = _engine.position;
            _lastBufferedAhead = _engine.buffered;
            _lastProgress = DateTime.now();
            if (mounted) {
              setState(() {
                _error = null;
                _status = 'Reproduciendo';
              });
            }
            continue;
          }
          break;
        }
        break;
      }
    }

    if (mounted && !_session.isStopped) {
      setState(() => _status = 'No hay una fuente reproducible');
    }
  }

  int _bestSourceIndex({int? excluding}) {
    if (widget.entry.sources.isEmpty) return 0;
    final health = _health.snapshot();
    var bestIndex = excluding == null ? 0 : (excluding + 1) % widget.entry.sources.length;
    var bestScore = excluding == null
        ? double.negativeInfinity
        : _sourceRanker.score(
            health[widget.entry.sources[bestIndex].id] ?? SourceHealth.initial(),
          );

    for (var i = 0; i < widget.entry.sources.length; i++) {
      if (excluding != null && i == excluding) continue;
      final score = _sourceRanker.score(
        health[widget.entry.sources[i].id] ?? SourceHealth.initial(),
      );
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  void _advanceSource() {
    if (widget.entry.sources.isEmpty) return;
    _sourceIndex = _bestSourceIndex(excluding: _sourceIndex);
    _lastPosition = Duration.zero;
    _lastBufferedAhead = Duration.zero;
    _lastProgress = DateTime.now();
    _bufferHealthMonitor.reset();
    _stablePlaybackSince = null;
    _sourceAttemptStarted = null;
  }

  Future<void> _checkHealth() async {
    if (_session.isStopped || _recovering || _healthCheckRunning) return;
    final controller = _engine.controller;
    if (controller == null || !controller.value.isInitialized) return;

    // The native player can stop without emitting a useful error. Treat an
    // unexpected pause as a recoverable failure, but never fight an explicit
    // user pause.
    if (!controller.value.isPlaying) {
      if (!_userPaused &&
          _autoRecovery &&
          DateTime.now().difference(_lastProgress) >=
              const Duration(seconds: 5)) {
        await _recover(markFailure: true);
      }
      return;
    }

    _healthCheckRunning = true;
    try {
      final position = _engine.position;
      final playheadMoving = position > _lastPosition;
      final progressAt = DateTime.now();

      final bufferedAhead = _engine.buffered;
      final dataArriving = bufferedAhead > _lastBufferedAhead;
      _lastBufferedAhead = bufferedAhead;
      final buffering = controller.value.isBuffering;
      final ended = controller.value.isCompleted;

      final buffer = _bufferHealthMonitor.sample(
        bufferedAhead: bufferedAhead,
        playheadMoving: playheadMoving,
        buffering: buffering,
        now: progressAt,
      );

      if (playheadMoving) {
        _lastPosition = position;
        _lastProgress = progressAt;
        _stablePlaybackSince ??= progressAt;
        if (_stablePlaybackSince != null &&
            progressAt.difference(_stablePlaybackSince!) >=
                const Duration(seconds: 15)) {
          _recoveryCoordinator.resetAfterStablePlayback();
          _stablePlaybackSince = progressAt;
        }
        final source = widget.entry.sources.isEmpty
            ? null
            : widget.entry.sources[_sourceIndex];
        final started = _sourceAttemptStarted;
        if (source != null && started != null) {
          await _health.recordSuccess(
            source.id,
            progressAt,
            progressAt.difference(started),
          );
          _sourceAttemptStarted = null;
        }
        if (mounted && _status != 'Reproduciendo' && !buffer.degraded) {
          setState(() => _status = 'Reproduciendo');
        }
      }

      final age = progressAt.difference(_lastProgress);
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

      if (mounted && buffering && !stalled) {
        setState(() => _status =
            buffer.degraded ? 'Buffer bajo · recuperando...' : 'Buffering');
      }
      if ((stalled || buffer.severe) && _autoRecovery) {
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
      _userPaused = true;
      await _engine.pause();
    } else {
      _userPaused = false;
      _lastProgress = DateTime.now();
      await _engine.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    _fullscreen = !_fullscreen;
    await SystemChrome.setEnabledSystemUIMode(
      _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    if (mounted) setState(() {});
  }

  Future<void> _recover(
      {bool retryable = true, bool markFailure = false}) async {
    if (_recovering || _session.isStopped) return;
    final source = widget.entry.sources.isEmpty
        ? null
        : widget.entry.sources[_sourceIndex];
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
            await _openSource(
                automatic: true,
                operationId: operation,
                allowNestedRecovery: false);
          }
        },
        allowSourceSwitch:
            _autoSourceSwitching && widget.entry.sources.length > 1,
        switchSource: () async {
          if (!_autoSourceSwitching || widget.entry.sources.length <= 1) {
            return;
          }
          if (_session.isCurrentOperation(operation)) {
            _advanceSource();
            await _openSource(
                automatic: true,
                operationId: operation,
                allowNestedRecovery: false);
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
        sourceId: widget.entry.sources.isEmpty
            ? null
            : widget.entry.sources[_sourceIndex].id,
      ));
    }
    _session.stop();
    _recoveryCoordinator.cancel();
    _playbackErrorSubscription?.cancel();
    _playbackStateSubscription?.cancel();
    _healthTimer?.cancel();
    _health.dispose();
    _engine.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_recovering ? Icons.sync : Icons.tv_off, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _recovering ? null : _recover,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final activeController = controller;
    final isLive = activeController.value.duration <= Duration.zero;
    final playing = activeController.value.isPlaying;
    final aspectRatio = activeController.value.aspectRatio > 0
        ? activeController.value.aspectRatio
        : 16 / 9;

    final video = Focus(
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
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.f11) {
          unawaited(_toggleFullscreen());
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: VideoPlayer(activeController),
              ),
            ),
            if (activeController.value.isBuffering || _recovering)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(_recovering ? 'Recuperando conexión…' : 'Buffering…'),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                child: Row(
                  children: [
                    if (!_fullscreen)
                      IconButton(
                        tooltip: 'Volver',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 9),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.entry.channel.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isLive ? 'EN VIVO' : _status,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Row(
                      children: [
                        TvFocusable(
                          onActivate: () => unawaited(_togglePlayback()),
                          child: IconButton(
                            tooltip: playing ? 'Pausar' : 'Reproducir',
                            onPressed: () => unawaited(_togglePlayback()),
                            iconSize: 30,
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Recuperar',
                          onPressed: _recovering ? null : _recover,
                          icon: const Icon(Icons.refresh),
                        ),
                        Expanded(
                          child: Text(
                            _error ?? _status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('Fuente ' + (_sourceIndex + 1).toString() + '/' + widget.entry.sources.length.toString(), style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: _fullscreen ? 'Salir de pantalla completa' : 'Pantalla completa',
                          onPressed: _toggleFullscreen,
                          icon: Icon(
                            _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) {
          unawaited(_toggleFullscreen());
        }
      },
      child: Scaffold(
        appBar: _fullscreen
            ? null
            : AppBar(
                title: Text(widget.entry.channel.displayName),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(child: Text(_status)),
                  ),
                ],
              ),
        backgroundColor: Colors.black,
        body: Center(child: video),
      ),
    );
  }