import '../../domain/entities/stream_source.dart';

enum HardwareDecodeMode { automatic, enabled, disabled }

class PlaybackRequest {
  const PlaybackRequest({
    required this.source,
    this.userAgent,
    this.headers = const <String, String>{},
    this.cookies = const <String, String>{},
    this.hardwareDecode = HardwareDecodeMode.automatic,
    this.preferredBitrate,
  });

  final StreamSource source;
  final String? userAgent;
  final Map<String, String> headers;
  final Map<String, String> cookies;
  final HardwareDecodeMode hardwareDecode;
  final int? preferredBitrate;

  Map<String, String> get effectiveHeaders {
    final merged = <String, String>{...source.headers, ...headers};
    if (userAgent != null && userAgent!.isNotEmpty) {
      merged['User-Agent'] = userAgent!;
    } else if (source.userAgent != null && source.userAgent!.isNotEmpty) {
      merged['User-Agent'] = source.userAgent!;
    }
    if (cookies.isNotEmpty) {
      merged['Cookie'] = cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
    }
    return Map.unmodifiable(merged);
  }
}
