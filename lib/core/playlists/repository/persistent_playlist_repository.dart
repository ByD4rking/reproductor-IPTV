import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';
import 'playlist_repository.dart';
import 'playlist_storage.dart';
import 'playlist_storage_factory.dart';

class PersistentPlaylistRepository implements PlaylistRepository {
  PersistentPlaylistRepository({
    SharedPreferencesAsync? preferences,
    PlaylistStorage? storage,
  })  : _legacyPreferences = preferences ?? SharedPreferencesAsync(),
        _store = storage ?? createPlaylistStorage();

  static const _legacyKey = 'playlists.v1';

  final SharedPreferencesAsync _legacyPreferences;
  final PlaylistStorage _store;
  final Map<String, Playlist> _items = <String, Playlist>{};
  bool _loaded = false;
  Future<void> _writeQueue = Future<void>.value();

  @override
  List<Playlist> get playlists =>
      List.unmodifiable(_items.values.toList(growable: false));

  @override
  Playlist? getById(String id) => _items[id];

  @override
  Future<void> load() async {
    if (_loaded) return;

    final values = await _store.load();

    // Migrate the old SharedPreferences payload once. The new store keeps
    // each playlist independently so adding/removing one list never rewrites
    // the entire library and large M3U files are no longer stored in prefs.
    if (values.isEmpty) {
      final legacy = await _legacyPreferences.getStringList(_legacyKey);
      if (legacy != null && legacy.isNotEmpty) {
        for (final raw in legacy) {
          try {
            final playlist = _decode(jsonDecode(raw) as Map<String, dynamic>);
            await _store.save(playlist.id, raw);
            values[playlist.id] = raw;
          } catch (_) {}
        }
        if (values.isNotEmpty) {
          await _legacyPreferences.remove(_legacyKey);
        }
      }
    }

    for (final raw in values.values) {
      try {
        final playlist = _decode(jsonDecode(raw) as Map<String, dynamic>);
        _items[playlist.id] = playlist;
      } catch (_) {
        // A damaged playlist must not prevent the remaining library loading.
      }
    }
    _loaded = true;
  }

  @override
  Future<void> upsert(Playlist playlist) => _write(() async {
        await load();
        _items[playlist.id] = playlist;
        await _store.save(playlist.id, jsonEncode(_encode(playlist)));
      });

  @override
  Future<void> remove(String id) => _write(() async {
        await load();
        _items.remove(id);
        await _store.remove(id);
      });

  @override
  Future<void> clear() => _write(() async {
        await load();
        _items.clear();
        await _store.clear();
      });

  Future<void> _write(Future<void> Function() action) {
    final operation = _writeQueue.then((_) => action());
    _writeQueue = operation.catchError((_) {});
    return operation;
  }

  Map<String, dynamic> _encode(Playlist p) => {
        'id': p.id,
        'name': p.name,
        'sourceUri': p.sourceUri?.toString(),
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
                      .toList(growable: false),
                })
            .toList(growable: false),
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
        logoUrl:
            e['logoUrl'] == null ? null : Uri.parse(e['logoUrl'] as String),
      );
    }).toList(growable: false);

    return Playlist(
      id: map['id'] as String,
      name: map['name'] as String,
      entries: entries,
      sourceUri: map['sourceUri'] == null
          ? null
          : Uri.tryParse(map['sourceUri'] as String),
      rawContentHash: map['rawContentHash'] as String?,
      updatedAt: map['updatedAt'] == null
          ? null
          : DateTime.parse(map['updatedAt'] as String),
    );
  }
}
