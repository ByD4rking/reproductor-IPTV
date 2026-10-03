import '../../domain/entities/playlist.dart';

abstract interface class PlaylistRepository {
  List<Playlist> get playlists;
  Playlist? getById(String id);
  Future<void> upsert(Playlist playlist);
  Future<void> remove(String id);
  Future<void> clear();
}
