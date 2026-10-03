enum StreamKind { hls, dash, progressive, unknown }

class StreamKindDetector {
  const StreamKindDetector();

  StreamKind detect(Uri uri, {String? contentType}) {
    final mime = contentType?.toLowerCase().split(';').first.trim();
    if (mime == 'application/vnd.apple.mpegurl' ||
        mime == 'application/x-mpegurl' ||
        mime == 'audio/mpegurl') {
      return StreamKind.hls;
    }
    if (mime == 'application/dash+xml') return StreamKind.dash;

    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) return StreamKind.hls;
    if (path.endsWith('.mpd')) return StreamKind.dash;
    if (mime == 'video/mp2t' ||
        mime == 'video/mp4' ||
        mime == 'video/webm' ||
        mime == 'audio/mpeg') {
      return StreamKind.progressive;
    }
    return StreamKind.unknown;
  }
}
