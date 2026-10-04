import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/watch_history.dart';
import '../storage/atomic_string_list_store.dart';

class HistoryRepository {
  HistoryRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'history.v1';
  final AtomicStringListStore _store;

  Future<List<WatchHistoryEntry>> load() async {
    final raw = await _store.load();
    return raw
        .map((value) {
          try {
            final map = jsonDecode(value) as Map<String, dynamic>;
            return WatchHistoryEntry(
              channelId: map['channelId'] as String,
              startedAt: DateTime.parse(map['startedAt'] as String),
              duration:
                  Duration(milliseconds: (map['durationMs'] as num).toInt()),
              playlistId: map['playlistId'] as String?,
              sourceId: map['sourceId'] as String?,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<WatchHistoryEntry>()
        .toList(growable: false);
  }

  Future<void> add(WatchHistoryEntry entry) async {
    final values = await load();
    final next = <WatchHistoryEntry>[entry, ...values].take(100).toList();
    await _store.save(next
        .map((v) => jsonEncode({
              'channelId': v.channelId,
              'startedAt': v.startedAt.toIso8601String(),
              'durationMs': v.duration.inMilliseconds,
              'playlistId': v.playlistId,
              'sourceId': v.sourceId,
            }))
        .toList(growable: false));
  }

  Future<void> clear() => _store.clear();
}
