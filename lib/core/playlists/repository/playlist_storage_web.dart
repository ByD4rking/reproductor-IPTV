import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'playlist_storage.dart';

PlaylistStorage createPlaylistStorageImpl() => _WebPlaylistStorage();

class _WebPlaylistStorage implements PlaylistStorage {
  _WebPlaylistStorage({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _indexKey = 'playlist-files.v2.index';

  Future<List<String>> _ids() =>
      _preferences.getStringList(_indexKey).then(
            (value) => value ?? const <String>[],
          );

  @override
  Future<Map<String, String>> load() async {
    final ids = await _ids();
    final result = <String, String>{};
    for (final id in ids) {
      final value = await _preferences.getString(_key(id));
      if (value != null) {
        try {
          final map = jsonDecode(value) as Map<String, dynamic>;
          if (map['id'] == id) result[id] = value;
        } catch (_) {}
      }
    }
    return result;
  }

  @override
  Future<void> save(String id, String value) async {
    final ids = (await _ids()).toSet();
    ids.add(id);
    await _preferences.setString(_key(id), value);
    await _preferences.setStringList(_indexKey, ids.toList(growable: false));
  }

  @override
  Future<void> remove(String id) async {
    final ids = (await _ids()).toSet()..remove(id);
    await _preferences.remove(_key(id));
    await _preferences.setStringList(_indexKey, ids.toList(growable: false));
  }

  @override
  Future<void> clear() async {
    final ids = await _ids();
    for (final id in ids) {
      await _preferences.remove(_key(id));
    }
    await _preferences.remove(_indexKey);
  }

  String _key(String id) =>
      'playlist-file.v2.${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';
}
