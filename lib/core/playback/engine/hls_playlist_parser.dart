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
    final normalized = body.startsWith('\uFEFF') ? body.substring(1) : body;
    final lines = normalized
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty || lines.first != '#EXTM3U') {
      return _invalid();
    }

    final uris = <Uri>[];
    var isMaster = false;
    Duration? targetDuration;
    var hasMediaSegment = false;
    var hasStreamInf = false;
    var hasPart = false;
    var hasStructure = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line == '#EXT-X-STREAM-INF' ||
          line.startsWith('#EXT-X-STREAM-INF:')) {
        hasStreamInf = true;
        isMaster = true;
        hasStructure = true;
        final uri = _nextUri(lines, i);
        if (uri != null) uris.add(baseUri.resolveUri(uri));
        continue;
      }

      if (line.startsWith('#EXT-X-I-FRAME-STREAM-INF:')) {
        isMaster = true;
        hasStructure = true;
        final uri = _attributeUri(line, 'URI');
        if (uri != null) uris.add(baseUri.resolveUri(uri));
        continue;
      }

      if (line.startsWith('#EXT-X-TARGETDURATION:')) {
        final value = int.tryParse(
          line.substring('#EXT-X-TARGETDURATION:'.length),
        );
        if (value != null && value > 0) {
          targetDuration = Duration(seconds: value);
          hasStructure = true;
        }
      }

      if (line.startsWith('#EXTINF:')) {
        hasMediaSegment = true;
        hasStructure = true;
        final uri = _nextUri(lines, i);
        if (uri != null) uris.add(baseUri.resolveUri(uri));
      }

      if (line.startsWith('#EXT-X-MAP:')) {
        hasStructure = true;
        final uri = _attributeUri(line, 'URI');
        if (uri != null) uris.add(baseUri.resolveUri(uri));
      }

      if (line.startsWith('#EXT-X-PART:')) {
        hasPart = true;
        hasStructure = true;
        final uri = _attributeUri(line, 'URI');
        if (uri != null) uris.add(baseUri.resolveUri(uri));
      }

      if (line.startsWith('#EXT-X-PRELOAD-HINT:')) {
        hasPart = true;
        hasStructure = true;
        final uri = _attributeUri(line, 'URI');
        if (uri != null) uris.add(baseUri.resolveUri(uri));
      }
    }

    final isValid =
        hasStructure && (hasStreamInf || hasMediaSegment || hasPart);
    final isLive = isValid && !lines.contains('#EXT-X-ENDLIST');

    return HlsPlaylist(
      isValid: isValid,
      isMaster: isMaster || hasStreamInf,
      uris: List.unmodifiable(uris),
      targetDuration: targetDuration,
      isLive: isLive,
    );
  }

  static HlsPlaylist _invalid() => const HlsPlaylist(
        isValid: false,
        isMaster: false,
        uris: <Uri>[],
        targetDuration: null,
        isLive: false,
      );

  static Uri? _nextUri(List<String> lines, int index) {
    if (index + 1 >= lines.length || lines[index + 1].startsWith('#')) {
      return null;
    }
    return Uri.tryParse(lines[index + 1]);
  }

  static Uri? _attributeUri(String line, String attribute) {
    final match = RegExp(
      '$attribute="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(line);
    return match == null ? null : Uri.tryParse(match.group(1)!);
  }
}
