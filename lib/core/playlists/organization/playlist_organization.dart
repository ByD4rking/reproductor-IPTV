import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';

class PlaylistFolder {
  const PlaylistFolder({required this.id, required this.name, required this.order, this.hidden = false, this.custom = true});
  final String id;
  final String name;
  final int order;
  final bool hidden;
  final bool custom;

  PlaylistFolder copyWith({String? name, int? order, bool? hidden}) => PlaylistFolder(
    id: id, name: name ?? this.name, order: order ?? this.order,
    hidden: hidden ?? this.hidden, custom: custom,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'order': order, 'hidden': hidden, 'custom': custom};

  static PlaylistFolder fromJson(Map<String, dynamic> json) => PlaylistFolder(
    id: json['id'] as String, name: json['name'] as String,
    order: (json['order'] as num).toInt(), hidden: json['hidden'] as bool? ?? false,
    custom: json['custom'] as bool? ?? true,
  );
}

class PlaylistOrganization {
  const PlaylistOrganization({this.folders = const <PlaylistFolder>[], this.assignments = const <String, String>{}});
  final List<PlaylistFolder> folders;
  final Map<String, String> assignments;

  PlaylistOrganization copyWith({List<PlaylistFolder>? folders, Map<String, String>? assignments}) =>
      PlaylistOrganization(
        folders: List.unmodifiable(folders ?? this.folders),
        assignments: Map.unmodifiable(assignments ?? this.assignments),
      );

  Map<String, dynamic> toJson() => {
    'folders': folders.map((folder) => folder.toJson()).toList(),
    'assignments': assignments,
  };

  static PlaylistOrganization fromJson(Map<String, dynamic> json) {
    final folders = (json['folders'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((value) => PlaylistFolder.fromJson(Map<String, dynamic>.from(value)))
        .toList();
    final rawAssignments = Map<String, dynamic>.from(
      json['assignments'] as Map? ?? const <String, dynamic>{},
    );
    return PlaylistOrganization(
      folders: folders,
      assignments: {for (final entry in rawAssignments.entries) entry.key: entry.value.toString()},
    );
  }
}

class PlaylistOrganizationRepository {
  PlaylistOrganizationRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'playlist.organization.v1';
  static Future<void> _writeQueue = Future<void>.value();

  static String entryKey(PlaylistEntry entry) =>
      entry.channel.tvgId?.trim().isNotEmpty == true
          ? entry.channel.tvgId!.trim()
          : entry.channel.id;
  final SharedPreferencesAsync _preferences;

  Future<PlaylistOrganization> load(String playlistId) async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const PlaylistOrganization();
    }
    try {
      final root = jsonDecode(raw) as Map<String, dynamic>;
      final value = root[playlistId];
      if (value is Map) {
        return PlaylistOrganization.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {}
    return const PlaylistOrganization();
  }

  Future<void> save(String playlistId, PlaylistOrganization organization) =>
      _enqueue(() => _saveNow(playlistId, organization));

  Future<void> _saveNow(
    String playlistId,
    PlaylistOrganization organization,
  ) async {
    final root = <String, dynamic>{};
    final raw = await _preferences.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        root.addAll(Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {}
    }
    root[playlistId] = organization.toJson();
    await _preferences.setString(_key, jsonEncode(root));
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    // Keep the queue alive after a failed write without erasing the original
    // operation's error for its caller.
    _writeQueue = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return next;
  }

  Future<void> removePlaylist(String playlistId) =>
      _enqueue(() async {
        final raw = await _preferences.getString(_key);
        if (raw == null || raw.isEmpty) return;
        try {
          final root = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          root.remove(playlistId);
          await _preferences.setString(_key, jsonEncode(root));
        } catch (_) {}
      });

  Future<PlaylistOrganization> syncWithGroups(String playlistId, Iterable<String> groupNames) {
    final names = groupNames.toList(growable: false);
    return _enqueue(() async {
    final current = await load(playlistId);
    final folders = [...current.folders];
    final ids = folders.map((folder) => folder.id).toSet();
    for (final rawName in names) {
      final name = rawName.trim().isEmpty ? 'Sin categoría' : rawName.trim();
      final id = 'group:${name.toLowerCase()}';
      if (ids.add(id)) {
        folders.add(PlaylistFolder(id: id, name: name, order: folders.length, custom: false));
      }
    }
    final validIds = folders.map((folder) => folder.id).toSet();
    final assignments = <String, String>{
      for (final entry in current.assignments.entries) if (validIds.contains(entry.value)) entry.key: entry.value,
    };
    final next = current.copyWith(folders: folders, assignments: assignments);
    await _saveNow(playlistId, next);
    return next;
    });
  }

  Future<PlaylistFolder> createFolder(String playlistId, String name) {
    final clean = name.trim();
    return _enqueue(() async {
    if (clean.isEmpty) {
      throw const FormatException('El nombre no puede estar vacío.');
    }
    final current = await load(playlistId);
    final folder = PlaylistFolder(
      id: 'custom:${DateTime.now().microsecondsSinceEpoch}',
      name: clean, order: current.folders.length, custom: true,
    );
    await _saveNow(playlistId, current.copyWith(folders: [...current.folders, folder]));
    return folder;
    });
  }

  Future<void> renameFolder(String playlistId, String folderId, String name) {
    final clean = name.trim();
    return _enqueue(() async {
    if (clean.isEmpty) {
      throw const FormatException('El nombre no puede estar vacío.');
    }
    final current = await load(playlistId);
    final folders = current.folders.map((folder) =>
      folder.id == folderId ? folder.copyWith(name: clean) : folder).toList();
    await _saveNow(playlistId, current.copyWith(folders: folders));
    });
  }

  Future<void> deleteFolder(String playlistId, String folderId) =>
      _enqueue(() async {
    final current = await load(playlistId);
    final matches = current.folders.where((item) => item.id == folderId);
    if (matches.isEmpty || !matches.first.custom) {
      throw StateError('Las categorías originales de la M3U no se eliminan.');
    }
    final folders = current.folders.where((item) => item.id != folderId).toList();
    final assignments = Map<String, String>.from(current.assignments)..removeWhere((_, value) => value == folderId);
    await _saveNow(playlistId, current.copyWith(folders: folders, assignments: assignments));
      });

  Future<void> moveEntry(String playlistId, String entryId, String? folderId) =>
      _enqueue(() async {
    final current = await load(playlistId);
    final assignments = Map<String, String>.from(current.assignments);
    if (folderId == null) {
      assignments.remove(entryId);
    } else {
      assignments[entryId] = folderId;
    }
    await _saveNow(playlistId, current.copyWith(assignments: assignments));
      });

  Future<void> reorder(String playlistId, String folderId, int delta) =>
      _enqueue(() async {
    final current = await load(playlistId);
    final ordered = [...current.folders]..sort((a, b) => a.order.compareTo(b.order));
    final index = ordered.indexWhere((folder) => folder.id == folderId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= ordered.length) {
      return;
    }
    final item = ordered.removeAt(index);
    ordered.insert(target, item);
    final folders = [for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(order: i)];
    await _saveNow(playlistId, current.copyWith(folders: folders));
      });
}
