import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/favorite.dart';

class FavoriteRepository {
  FavoriteRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'favorites.v1';
  final SharedPreferencesAsync _preferences;

  Future<List<Favorite>> load() async {
    final raw = await _preferences.getStringList(_key) ?? const <String>[];
    return raw.map((value) {
      try {
        final map = jsonDecode(value) as Map<String, dynamic>;
        return Favorite(
          channelId: map['channelId'] as String,
          preferredPlaylistId: map['preferredPlaylistId'] as String?,
          preferredSourceId: map['preferredSourceId'] as String?,
        );
      } catch (_) {
        return null;
      }
    }).whereType<Favorite>().toList(growable: false);
  }

  Future<void> setFavorite(Favorite favorite) async {
    final values = await load();
    final next = values.where((v) => v.channelId != favorite.channelId).toList()
      ..add(favorite);
    await _save(next);
  }

  Future<void> remove(String channelId) async {
    final values = await load();
    await _save(values.where((v) => v.channelId != channelId).toList());
  }

  Future<void> _save(List<Favorite> values) => _preferences.setStringList(
    _key,
    values.map((v) => jsonEncode({
      'channelId': v.channelId,
      'preferredPlaylistId': v.preferredPlaylistId,
      'preferredSourceId': v.preferredSourceId,
    })).toList(),
  );
}
