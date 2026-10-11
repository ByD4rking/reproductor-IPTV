import 'package:video_player/video_player.dart';

/// Infers container hints from both the path and common IPTV query formats.
/// Xtream-style endpoints often put the format in query parameters rather than
/// ending the URL path with ".m3u8" or ".mpd".
VideoFormat? streamFormatHint(Uri uri) {
  final path = uri.path.toLowerCase();
  if (path.endsWith('.m3u8')) return VideoFormat.hls;
  if (path.endsWith('.mpd')) return VideoFormat.dash;

  const formatKeys = <String>{
    'type',
    'output',
    'format',
    'container',
    'extension',
    'stream_type',
  };
  for (final entry in uri.queryParametersAll.entries) {
    if (!formatKeys.contains(entry.key.toLowerCase())) continue;
    for (final raw in entry.value) {
      final value = raw.trim().toLowerCase();
      if (value == 'hls' || value.contains('m3u8')) {
        return VideoFormat.hls;
      }
      if (value == 'dash' || value == 'mpd') {
        return VideoFormat.dash;
      }
    }
  }
  return null;
}
