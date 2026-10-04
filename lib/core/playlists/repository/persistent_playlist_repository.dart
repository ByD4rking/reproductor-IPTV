import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';
import '../../storage/atomic_string_list_store.dart';
import 'playlist_repository.dart';

class PersistentPlaylistRepository implements PlaylistRepository {
  PersistentPlaylistRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'playlists.v1';
  final AtomicStringListStore _store;
  final Map<String, Playlist> _items = <String, Playlist>{};
  bool _loaded = false;

  @override
  List<Playlist> get playlists =>
      List.unmodifiable(_items.values.toList(growable: false));

  @override
  Playlist? getById(String id) => _items[id];

  Future<void> load() async {
    if (_loaded) return;
    final values = await _store.load();
    for (final raw in values) {
      try {
        final playlist = _decode(jsonDecode(raw) as Map<String, dynamic>);
        _items[playlist.id] = playlist;
      } catch (_) {}
    }
    _loaded = true;
  }

  @override
  Future<void> upsert(Playlist playlist) async {
    await load();
    _items[playlist.id] = playlist;
    await _flush();
  }

  @override
  Future<void> remove(String id) async {
    await load();
    _items.remove(id);
    await _flush();
  }

  @override
  Future<void> clear() async {
    _items.clear();
    _loaded = true;
    await _store.clear();
  }

  Future<void> _flush() async => _store.save(
        _items.values
            .map((p) => jsonEncode(_encode(p)))
            .toList(growable: false),
      );

  Map<String, dynamic> _encode(Playlist p) => {
        'id': p.id,
        'name': p.name,
        'rawContentHash': p.rawContentHash,
        'updatedAt': p.updatedAt?.toIso8601String(),
        'entries': p.entries
            .map((e) => {
                  'id': e.id,
                  'channel': {
                    'id': e.channel.id,
                    'displayName': e.channel.displayName,
                    'tvgId': e.channel.tvgId,
                    'country': e.channel.country,
                    'language': e.channel.language,
                  },
                  'category': e.category,
                  'logoUrl': e.logoUrl?.toString(),
                  'sources': e.sources
                      .map((s) => {
                            'id': s.id,
                            'url': s.url.toString(),
                            'userAgent': s.userAgent,
                            'headers': s.headers,
                          })
                      .toList(),
                })
            .toList(),
      };

  Playlist _decode(Map<String, dynamic> map) {
    final entries = (map['entries'] as List<dynamic>).map((item) {
      final e = item as Map<String, dynamic>;
      final c = e['channel'] as Map<String, dynamic>;
      final sources = (e['sources'] as List<dynamic>).map((raw) {
        final s = raw as Map<String, dynamic>;
        return StreamSource(
          id: s['id'] as String,
          url: Uri.parse(s['url'] as String),
          userAgent: s['userAgent'] as String?,
          headers: Map<String, String>.from(s['headers'] as Map),
        );
      }).toList(growable: false);
      return PlaylistEntry(
        id: e['id'] as String,
        channel: Channel(
          id: c['id'] as String,
          displayName: c['displayName'] as String,
          tvgId: c['tvgId'] as String?,
          country: c['country'] as String?,
          language: c['language'] as String?,
        ),
        sources: sources,
        category: e['category'] as String?,
        logoUrl: e['logoUrl'] == null
            ? null
            : Uri.parse(e['logoUrl'] as String),
      );
    }).toList(growable: false);

    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      entries: entries,
      rawContentHash: map['rawContentHash'] as String?,
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}
