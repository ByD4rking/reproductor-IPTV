import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum RemotePlaylistState { active, stale, updating, failed }

class RemotePlaylistStatus {
  const RemotePlaylistStatus({
    required this.playlistId,
    required this.state,
    required this.updatedAt,
    this.uri,
    this.lastGoodHash,
    this.lastError,
  });

  final String playlistId;
  final RemotePlaylistState state;
  final DateTime updatedAt;
  final Uri? uri;
  final String? lastGoodHash;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'state': state.name,
        'updatedAt': updatedAt.toIso8601String(),
        'uri': uri?.toString(),
        'lastGoodHash': lastGoodHash,
        'lastError': lastError,
      };

  static RemotePlaylistStatus fromJson(Map<String, dynamic> json) {
    return RemotePlaylistStatus(
      playlistId: json['playlistId'] as String,
      state: RemotePlaylistState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => RemotePlaylistState.failed,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      uri: json['uri'] == null ? null : Uri.parse(json['uri'] as String),
      lastGoodHash: json['lastGoodHash'] as String?,
      lastError: json['lastError'] as String?,
    );
  }
}

class RemotePlaylistStateRepository {
  RemotePlaylistStateRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'remote-playlists.v1';
  final SharedPreferencesAsync _preferences;
  final Map<String, RemotePlaylistStatus> _items =
      <String, RemotePlaylistStatus>{};
  bool _loaded = false;

  Future<RemotePlaylistStatus?> get(String playlistId) async {
    await _load();
    return _items[playlistId];
  }

  Future<void> markUpdating(String playlistId, Uri uri) async {
    await _set(
      RemotePlaylistStatus(
        playlistId: playlistId,
        state: RemotePlaylistState.updating,
        updatedAt: DateTime.now(),
        uri: uri,
        lastGoodHash: _items[playlistId]?.lastGoodHash,
      ),
    );
  }

  Future<void> markActive(
    String playlistId,
    Uri uri,
    String? hash,
  ) async {
    await _set(
      RemotePlaylistStatus(
        playlistId: playlistId,
        state: RemotePlaylistState.active,
        updatedAt: DateTime.now(),
        uri: uri,
        lastGoodHash: hash ?? _items[playlistId]?.lastGoodHash,
      ),
    );
  }

  Future<void> markFailed(
    String playlistId,
    Uri uri,
    String error,
  ) async {
    await _set(
      RemotePlaylistStatus(
        playlistId: playlistId,
        state: RemotePlaylistState.failed,
        updatedAt: DateTime.now(),
        uri: uri,
        lastGoodHash: _items[playlistId]?.lastGoodHash,
        lastError: error.length > 512 ? error.substring(0, 512) : error,
      ),
    );
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final raw = await _preferences.getStringList(_key) ?? const <String>[];
    for (final value in raw) {
      try {
        final status = RemotePlaylistStatus.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
        _items[status.playlistId] = status;
      } catch (_) {}
    }
  }

  Future<void> _set(RemotePlaylistStatus status) async {
    await _load();
    _items[status.playlistId] = status;
    await _preferences.setStringList(
      _key,
      _items.values.map((value) => jsonEncode(value.toJson())).toList(),
    );
  }
}
