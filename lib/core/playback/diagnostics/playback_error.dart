import 'dart:async';

enum PlaybackErrorKind {
  network,
  timeout,
  unauthorized,
  notFound,
  malformedStream,
  unsupportedFormat,
  stalled,
  decoder,
  unknown,
}

enum ErrorDisposition { retry, switchSource, terminal }

class PlaybackError {
  const PlaybackError({
    required this.kind,
    required this.message,
    required this.disposition,
  });

  final PlaybackErrorKind kind;
  final String message;
  final ErrorDisposition disposition;
}

class PlaybackErrorClassifier {
  const PlaybackErrorClassifier();

  PlaybackError classify(int? statusCode, Object? error) {
    if (statusCode == 401 || statusCode == 403) {
      return const PlaybackError(
        kind: PlaybackErrorKind.unauthorized,
        message: 'Authentication required',
        disposition: ErrorDisposition.switchSource,
      );
    }
    if (statusCode == 404 || statusCode == 410) {
      return const PlaybackError(
        kind: PlaybackErrorKind.notFound,
        message: 'Stream not found',
        disposition: ErrorDisposition.switchSource,
      );
    }
    if (statusCode == 408 || statusCode == 429 ||
        (statusCode != null && statusCode >= 500)) {
      return const PlaybackError(
        kind: PlaybackErrorKind.network,
        message: 'Upstream/network error',
        disposition: ErrorDisposition.retry,
      );
    }
    if (error is TimeoutException) {
      return const PlaybackError(
        kind: PlaybackErrorKind.timeout,
        message: 'Network timeout',
        disposition: ErrorDisposition.retry,
      );
    }
    if (error is FormatException) {
      return const PlaybackError(
        kind: PlaybackErrorKind.malformedStream,
        message: 'Malformed media or manifest',
        disposition: ErrorDisposition.switchSource,
      );
    }
    if (error is UnsupportedError) {
      return const PlaybackError(
        kind: PlaybackErrorKind.unsupportedFormat,
        message: 'Unsupported media format',
        disposition: ErrorDisposition.switchSource,
      );
    }
    if (error is StateError) {
      return const PlaybackError(
        kind: PlaybackErrorKind.decoder,
        message: 'Playback state/decoder failure',
        disposition: ErrorDisposition.retry,
      );
    }
    return const PlaybackError(
      kind: PlaybackErrorKind.unknown,
      message: 'Unknown playback error',
      disposition: ErrorDisposition.retry,
    );
  }

  PlaybackError stalled() => const PlaybackError(
        kind: PlaybackErrorKind.stalled,
        message: 'Playback stalled',
        disposition: ErrorDisposition.retry,
      );
}
