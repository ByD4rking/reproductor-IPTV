import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'playlist_storage.dart';

PlaylistStorage createPlaylistStorageImpl() => _IoPlaylistStorage();

class _IoPlaylistStorage implements PlaylistStorage {
  Directory? _directory;

  Future<Directory> get _root async {
    final existing = _directory;
    if (existing != null) return existing;
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/playlists');
    await directory.create(recursive: true);
    _directory = directory;
    return directory;
  }

  String _fileName(String id) =>
      base64Url.encode(utf8.encode(id)).replaceAll('=', '') + '.json';

  @override
  Future<Map<String, String>> load() async {
    final directory = await _root;
    final result = <String, String>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final value = await entity.readAsString();
        final map = jsonDecode(value) as Map<String, dynamic>;
        final id = map['id'] as String?;
        if (id != null && id.isNotEmpty) {
          result[id] = value;
        }
      } catch (_) {
        // Ignore one corrupt playlist instead of losing the whole library.
      }
    }
    return result;
  }

  @override
  Future<void> save(String id, String value) async {
    final directory = await _root;
    final target = File('${directory.path}/${_fileName(id)}');
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(value, flush: true);
    if (await target.exists()) {
      await target.delete();
    }
    await temporary.rename(target.path);
  }

  @override
  Future<void> remove(String id) async {
    final directory = await _root;
    final target = File('${directory.path}/${_fileName(id)}');
    if (await target.exists()) {
      await target.delete();
    }
  }

  @override
  Future<void> clear() async {
    final directory = await _root;
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.json')) {
        await entity.delete();
      }
    }
  }
}
