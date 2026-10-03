class Favorite {
  const Favorite({
    required this.channelId,
    this.preferredPlaylistId,
    this.preferredSourceId,
  });

  final String channelId;
  final String? preferredPlaylistId;
  final String? preferredSourceId;
}
