import 'channel.dart';
import 'media_content_profile.dart';
import 'stream_source.dart';

class PlaylistEntry {
  const PlaylistEntry(
      {required this.id,
      required this.channel,
      required this.sources,
      this.category,
      this.logoUrl,
      this.mediaContentProfile = MediaContentProfile.unknown});
  final String id;
  final Channel channel;
  final List<StreamSource> sources;
  final String? category;
  final Uri? logoUrl;
  final MediaContentProfile mediaContentProfile;
}

class Playlist {
  const Playlist(
      {required this.id,
      required this.name,
      required this.entries,
      this.sourceUri,
      this.rawContentHash,
      this.updatedAt});
  final String id;
  final String name;
  final List<PlaylistEntry> entries;

  /// Original remote playlist URL, when this playlist was imported from a URL.
  final Uri? sourceUri;
  final String? rawContentHash;
  final DateTime? updatedAt;
}
