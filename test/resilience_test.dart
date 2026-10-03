import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playback/monitor/stall_detector.dart';
import 'package:reproductor_iptv/core/playback/diagnostics/playback_error.dart';
import 'package:reproductor_iptv/core/network/url_policy.dart';

void main() {
  test('brief buffering is not treated as a hard stall', () {
    const d = StallDetector();
    expect(d.isStalled(lastProgressAge: const Duration(seconds: 2), buffering: true, dataArriving: false, playheadMoving: false), isFalse);
    expect(d.isStalled(lastProgressAge: const Duration(seconds: 6), buffering: true, dataArriving: false, playheadMoving: false), isTrue);
  });

  test('moving playhead prevents a false stall even while buffering', () {
    const d = StallDetector();
    expect(d.isStalled(lastProgressAge: const Duration(seconds: 20), buffering: true, dataArriving: false, playheadMoving: true), isFalse);
  });

  test('HTTP auth and not-found errors switch source', () {
    const c = PlaybackErrorClassifier();
    expect(c.classify(401, null).disposition, ErrorDisposition.switchSource);
    expect(c.classify(404, null).disposition, ErrorDisposition.switchSource);
    expect(c.classify(503, null).disposition, ErrorDisposition.retry);
  });

  test('URL policy blocks non-http schemes and excessive redirects', () {
    const p = UrlPolicy();
    expect(p.accepts(Uri.parse('https://example.com')), isTrue);
    expect(p.accepts(Uri.parse('file:///secret')), isFalse);
    expect(p.accepts(Uri.parse('https://user:pass@example.com')), isFalse);
    expect(p.acceptsRedirectCount(6), isFalse);
  });
}
