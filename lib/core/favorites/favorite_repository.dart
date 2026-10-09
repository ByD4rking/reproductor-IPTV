import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/favorite.dart';
import '../storage/atomic_string_list_store.dart';

class FavoriteRepository {
  FavoriteRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'favorites.v1';
  static Future<void> _writeQueue = Future<void>.value();
  final AtomicStringListStore _store;

  Future<List<Favorite>> load() async {
    final raw = await _store.load();
    return raw
        .map((value) {
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
        })
        .whereType<Favorite>()
        .toList(growable: false);
  }

  Future<void> setFavorite(Favorite favorite) => _enqueue(() async {
        if (favorite.channelId.trim().isEmpty) {
          throw const FormatException('El identificador del canal está vacío.');
        }
        final values = await load();
        final next = values
            .where((value) =>
                !(value.channelId == favorite.channelId &&
                    value.preferredPlaylistId == favorite.preferredPlaylistId))
            .toList()
          ..add(favorite);
        await _save(next);
      });

  Future<void> remove(
    String channelId, {
    String? playlistId,
  }) =>
      _enqueue(() async {
        final values = await load();
        await _save(
          values
              .where((value) =>
                  !(value.channelId == channelId &&
                      value.preferredPlaylistId == playlistId))
              .toList(),
        );
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _save(List<Favorite> values) => _store.save(
        values
            .map((v) => jsonEncode({
                  'channelId': v.channelId,
                  'preferredPlaylistId': v.preferredPlaylistId,
                  'preferredSourceId': v.preferredSourceId,
                }))
            .toList(growable: false),
      );
}
