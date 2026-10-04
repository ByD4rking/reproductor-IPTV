import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/stream_source.dart';
import '../../storage/atomic_string_list_store.dart';

class SourceHealthRepository {
  SourceHealthRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'source-health.v1';
  final AtomicStringListStore _store;
  bool _disposed = false;

  Future<Map<String, SourceHealth>> load() async {
    if (_disposed) return const <String, SourceHealth>{};
    final raw = await _store.load();
    final result = <String, SourceHealth>{};
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final sourceId = map['sourceId'] as String;
        result[sourceId] = _decode(map['health'] as Map<String, dynamic>);
      } catch (_) {}
    }
    return Map.unmodifiable(result);
  }

  Future<void> save(Map<String, SourceHealth> health) async {
    if (_disposed) return;
    final snapshot = health.entries
        .map((entry) => jsonEncode({
              'sourceId': entry.key,
              'health': _encode(entry.value),
            }))
        .toList(growable: false);
    await _store.save(snapshot);
  }

  void dispose() => _disposed = true;

  Map<String, dynamic> _encode(SourceHealth value) => {
        'state': value.state.name,
        'consecutiveFailures': value.consecutiveFailures,
        'lastSuccess': value.lastSuccess?.toIso8601String(),
        'lastFailure': value.lastFailure?.toIso8601String(),
        'responseTimeMs': value.responseTime?.inMilliseconds,
        'cooldownUntil': value.cooldownUntil?.toIso8601String(),
      };

  SourceHealth _decode(Map<String, dynamic> map) => SourceHealth(
        state: SourceHealthState.values.firstWhere(
          (value) => value.name == map['state'],
          orElse: () => SourceHealthState.healthy,
        ),
        consecutiveFailures: (map['consecutiveFailures'] as num?)?.toInt() ?? 0,
        lastSuccess: _date(map['lastSuccess']),
        lastFailure: _date(map['lastFailure']),
        responseTime: map['responseTimeMs'] == null
            ? null
            : Duration(milliseconds: (map['responseTimeMs'] as num).toInt()),
        cooldownUntil: _date(map['cooldownUntil']),
      );

  DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}
