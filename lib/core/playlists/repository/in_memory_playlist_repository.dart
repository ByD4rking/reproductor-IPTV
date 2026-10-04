import '../../domain/entities/playlist.dart';
import 'playlist_repository.dart';

class InMemoryPlaylistRepository implements PlaylistRepository {
  @override
  Future<void> load() async {}

  final Map<String, Playlist> _items = <String, Playlist>{};

  @override
  List<Playlist> get playlists =>
      List.unmodifiable(_items.values.toList(growable: false));
  @override
  Playlist? getById(String id) => _items[id];
  @override
  Future<void> upsert(Playlist playlist) async {
    _items[playlist.id] = playlist;
  }

  @override
  Future<void> remove(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> clear() async {
    _items.clear();
  }
}
