class PlaybackTrack {
  const PlaybackTrack({
    required this.id,
    required this.label,
    required this.kind,
    this.language,
    this.selected = false,
  });

  final String id;
  final String label;
  final String kind;
  final String? language;
  final bool selected;
}

class PlaybackTracks {
  const PlaybackTracks({
    this.video = const <PlaybackTrack>[],
    this.audio = const <PlaybackTrack>[],
    this.subtitles = const <PlaybackTrack>[],
  });

  final List<PlaybackTrack> video;
  final List<PlaybackTrack> audio;
  final List<PlaybackTrack> subtitles;
}
