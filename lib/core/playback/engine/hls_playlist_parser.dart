class HlsPlaylist {
  const HlsPlaylist({
    required this.isValid,
    required this.isMaster,
    required this.uris,
    required this.targetDuration,
    required this.isLive,
  });

  final bool isValid;
  final bool isMaster;
  final List<Uri> uris;
  final Duration? targetDuration;
  final bool isLive;
}

class HlsPlaylistParser {
  const HlsPlaylistParser();

  HlsPlaylist parse(String body, Uri baseUri) {
    final lines = body
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty || lines.first != '#EXTM3U') {
      return const HlsPlaylist(
        isValid: false,
        isMaster: false,
        uris: <Uri>[],
        targetDuration: null,
        isLive: false,
      );
    }

    final uris = <Uri>[];
    var isMaster = false;
    Duration? targetDuration;
    var hasMediaSegment = false;
    var hasStreamInf = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line == '#EXT-X-STREAM-INF' ||
          line.startsWith('#EXT-X-STREAM-INF:')) {
        hasStreamInf = true;
        isMaster = true;
        if (i + 1 < lines.length && !lines[i + 1].startsWith('#')) {
          final uri = Uri.tryParse(lines[i + 1]);
          if (uri != null) {
            uris.add(baseUri.resolveUri(uri));
          }
        }
        continue;
      }

      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        final value =
            int.tryParse(line.substring('#EXT-X-TARGETDURATION:'.length));
        if (value != null && value > 0) {
          targetDuration = Duration(seconds: value);
        }
      }

      if (line.startsWith('#EXTINF:')) {
        hasMediaSegment = true;
        if (i + 1 < lines.length && !lines[i + 1].startsWith('#')) {
          final uri = Uri.tryParse(lines[i + 1]);
          if (uri != null) {
            uris.add(baseUri.resolveUri(uri));
          }
        }
      }
    }

    final isValid = hasStreamInf || hasMediaSegment;
    final isLive = isValid && !lines.contains('#EXT-X-ENDLIST');

    return HlsPlaylist(
      isValid: isValid,
      isMaster: isMaster || hasStreamInf,
      uris: List.unmodifiable(uris),
      targetDuration: targetDuration,
      isLive: isLive,
    );
  }
}
