import 'playback_health_signals.dart';

enum PlaybackMediaMode { live, vod }

class BufferPolicyDecision {
  const BufferPolicyDecision({
    required this.targetBuffer,
    required this.stallGrace,
  });

  final Duration targetBuffer;
  final Duration stallGrace;
}

class AdaptiveBufferPolicy {
  const AdaptiveBufferPolicy({
    this.liveTarget = const Duration(seconds: 8),
    this.liveStableTarget = const Duration(seconds: 14),
    this.vodTarget = const Duration(seconds: 20),
    this.vodStableTarget = const Duration(seconds: 30),
    this.stallGrace = const Duration(seconds: 5),
  });

  final Duration liveTarget;
  final Duration liveStableTarget;
  final Duration vodTarget;
  final Duration vodStableTarget;
  final Duration stallGrace;

  BufferPolicyDecision decide({
    required PlaybackMediaMode mode,
    required PlaybackHealthSignals signals,
  }) {
    final unstable = signals.lastProgressAge >= stallGrace ||
        signals.bufferedAhead < const Duration(seconds: 2);
    if (mode == PlaybackMediaMode.live) {
      return BufferPolicyDecision(
        targetBuffer: unstable ? liveStableTarget : liveTarget,
        stallGrace: stallGrace,
      );
    }
    return BufferPolicyDecision(
      targetBuffer: unstable ? vodStableTarget : vodTarget,
      stallGrace: stallGrace,
    );
  }
}
