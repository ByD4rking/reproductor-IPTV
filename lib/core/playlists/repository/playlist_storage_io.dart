import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'playlist_storage.dart';

PlaylistStorage createPlaylistStorageImpl() => FilePlaylistStorage();

class FilePlaylistStorage implements PlaylistStorage {
  FilePlaylistStorage({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;
  Directory? _directory;
  final SharedPreferencesAsync _fallback = SharedPreferencesAsync();
  static const _fallbackIndexKey = 'playlist-files.v2.test-index';

  String _fileName(String id) =>
      '${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}.json';

  Future<Directory> get _root async {
    final existing = _directory;
    if (existing != null) return existing;
    final override = _rootOverride;
    if (override != null) {
      await override.create(recursive: true);
      _directory = override;
      return override;
    }
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      throw const FileSystemException('Use test storage fallback');
    }
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/playlists');
    await directory.create(recursive: true);
    _directory = directory;
    return directory;
  }

  @override
  Future<Map<String, String>> load() async {
    try {
      final directory = await _root;
      final result = <String, String>{};
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final value = await entity.readAsString();
          final map = jsonDecode(value) as Map<String, dynamic>;
          final id = map['id'] as String?;
          if (id != null && id.isNotEmpty) result[id] = value;
        } catch (_) {}
      }
      return result;
    } catch (_) {
      return _loadFallback();
    }
  }

  @override
  Future<void> save(String id, String value) async {
    try {
      final directory = await _root;
      final target = File('${directory.path}/${_fileName(id)}');
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(value, flush: true);
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
    } catch (_) {
      await _saveFallback(id, value);
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      final directory = await _root;
      final target = File('${directory.path}/${_fileName(id)}');
      if (await target.exists()) await target.delete();
    } catch (_) {
      final ids = (await _fallbackIds()).toSet()..remove(id);
      await _fallback.remove(_fallbackKey(id));
      await _fallback.setStringList(_fallbackIndexKey, ids.toList());
    }
  }

  @override
  Future<void> clear() async {
    try {
      final directory = await _root;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.json')) {
          await entity.delete();
        }
      }
    } catch (_) {
      for (final id in await _fallbackIds()) {
        await _fallback.remove(_fallbackKey(id));
      }
      await _fallback.remove(_fallbackIndexKey);
    }
  }

  Future<Map<String, String>> _loadFallback() async {
    final result = <String, String>{};
    for (final id in await _fallbackIds()) {
      final value = await _fallback.getString(_fallbackKey(id));
      if (value != null) result[id] = value;
    }
    return result;
  }

  Future<void> _saveFallback(String id, String value) async {
    final ids = (await _fallbackIds()).toSet()..add(id);
    await _fallback.setString(_fallbackKey(id), value);
    await _fallback.setStringList(_fallbackIndexKey, ids.toList());
  }

  Future<List<String>> _fallbackIds() =>
      _fallback.getStringList(_fallbackIndexKey).then(
            (value) => value ?? const <String>[],
          );

  String _fallbackKey(String id) =>
      'playlist-file.v2.${base64Url.encode(utf8.encode(id)).replaceAll('=', '')}';
}
