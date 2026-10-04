import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/engine/playback_engine_error.dart';

void main() {
  test('stale generation can be rejected by the playback owner', () {
    const currentGeneration = 8;
    const stale = PlaybackEngineError(
      generation: 7,
      sourceId: 'source-1',
      message: 'network error',
    );
    expect(stale.generation == currentGeneration, isFalse);
  });

  test('playback engine error keeps generation and source identity', () {
    const error = PlaybackEngineError(
      generation: 7,
      sourceId: 'source-7',
      message: 'HTTP 503',
    );

    expect(error.generation, 7);
    expect(error.sourceId, 'source-7');
    expect(error.message, 'HTTP 503');
  });

  test('playback engine error carries structured transport metadata', () {
    const error = PlaybackEngineError(
      generation: 3,
      sourceId: 'live-1',
      message: 'HTTP 503 Service Unavailable',
      code: 'timeout',
      statusCode: 503,
      behindLiveWindow: true,
    );

    expect(error.code, 'timeout');
    expect(error.statusCode, 503);
    expect(error.behindLiveWindow, isTrue);
  });
}
