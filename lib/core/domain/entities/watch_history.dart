class WatchHistoryEntry {
  const WatchHistoryEntry({
    required this.channelId,
    required this.startedAt,
    required this.duration,
    this.playlistId,
    this.sourceId,
  });

  final String channelId;
  final DateTime startedAt;
  final Duration duration;
  final String? playlistId;
  final String? sourceId;
}
