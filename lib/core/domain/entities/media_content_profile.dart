enum MediaContentType { live, vod, seriesEpisode, loopChannel, unknown }

enum MediaContentConfidence { high, medium, low }

enum MediaContentEvidence { declared, urlPattern, manifest, none }

class MediaContentProfile {
  const MediaContentProfile({
    required this.type,
    required this.confidence,
    required this.evidence,
  });

  static const unknown = MediaContentProfile(
    type: MediaContentType.unknown,
    confidence: MediaContentConfidence.low,
    evidence: MediaContentEvidence.none,
  );

  final MediaContentType type;
  final MediaContentConfidence confidence;
  final MediaContentEvidence evidence;

  bool get isKnown => type != MediaContentType.unknown;

  /// Uses explicit provider metadata first, then well-known Xtream URL paths.
  /// Channel names and group titles alone are deliberately not treated as proof.
  static MediaContentProfile fromM3u({
    required Map<String, String> attributes,
    required Uri url,
  }) {
    const metadataKeys = <String>[
      'tvg-type',
      'media-type',
      'content-type',
      'stream-type',
      'type',
    ];
    for (final key in metadataKeys) {
      final raw = attributes[key];
      if (raw == null || raw.trim().isEmpty) continue;
      final declared = _parseType(raw);
      if (declared != MediaContentType.unknown) {
        return MediaContentProfile(
          type: declared,
          confidence: MediaContentConfidence.high,
          evidence: MediaContentEvidence.declared,
        );
      }
    }

    final segments = url.path
        .toLowerCase()
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toSet();
    if (segments.contains('live') || segments.contains('livetv')) {
      return const MediaContentProfile(
        type: MediaContentType.live,
        confidence: MediaContentConfidence.medium,
        evidence: MediaContentEvidence.urlPattern,
      );
    }
    if (segments.contains('movie') || segments.contains('movies')) {
      return const MediaContentProfile(
        type: MediaContentType.vod,
        confidence: MediaContentConfidence.medium,
        evidence: MediaContentEvidence.urlPattern,
      );
    }
    if (segments.contains('series') || segments.contains('episode')) {
      return const MediaContentProfile(
        type: MediaContentType.seriesEpisode,
        confidence: MediaContentConfidence.medium,
        evidence: MediaContentEvidence.urlPattern,
      );
    }
    return unknown;
  }

  /// HLS media playlists without ENDLIST are live-like; master playlists do not
  /// identify content type and must not be classified from ENDLIST absence.
  static MediaContentProfile fromHlsManifest({
    required bool isMaster,
    required bool hasEndList,
  }) {
    if (isMaster) return unknown;
    return MediaContentProfile(
      type: hasEndList ? MediaContentType.vod : MediaContentType.live,
      confidence: MediaContentConfidence.medium,
      evidence: MediaContentEvidence.manifest,
    );
  }

  static MediaContentType _parseType(String raw) {
    final value = raw.trim().toLowerCase().replaceAll(RegExp(r'[ _]+'), '-');
    switch (value) {
      case 'live':
      case 'tv':
      case 'live-tv':
      case 'television':
      case 'linear':
        return MediaContentType.live;
      case 'vod':
      case 'movie':
      case 'movies':
      case 'film':
      case 'video-on-demand':
        return MediaContentType.vod;
      case 'series':
      case 'episode':
      case 'series-episode':
      case 'tv-series':
        return MediaContentType.seriesEpisode;
      case 'loop':
      case 'loop-channel':
      case 'linear-vod':
      case 'fast':
      case 'fast-channel':
        return MediaContentType.loopChannel;
      default:
        return MediaContentType.unknown;
    }
  }
}
