class PlaybackTrack {
  const PlaybackTrack({ required this.id, required this.label, required this.kind, this.language, this.selected = false, this.bitrate, this.width, this.height, this.frameRate, this.codec });
  final String id; final String label; final String kind; final String? language; final bool selected; final int? bitrate; final int? width; final int? height; final double? frameRate; final String? codec;
}
class PlaybackTracks {
  const PlaybackTracks({ this.video = const <PlaybackTrack>[], this.audio = const <PlaybackTrack>[], this.subtitles = const <PlaybackTrack>[] });
  final List<PlaybackTrack> video; final List<PlaybackTrack> audio; final List<PlaybackTrack> subtitles;
}