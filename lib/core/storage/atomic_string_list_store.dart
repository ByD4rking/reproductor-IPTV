import 'package:shared_preferences/shared_preferences.dart';

/// Crash-tolerant two-slot persistence for small ordered string snapshots.
///
/// A write lands in the inactive slot first and only then flips the active
/// pointer. If the process dies between those operations, the previous
/// snapshot remains authoritative.
class AtomicStringListStore {
  AtomicStringListStore({
    required SharedPreferencesAsync preferences,
    required String key,
  })  : _preferences = preferences,
        _key = key;

  final SharedPreferencesAsync _preferences;
  final String _key;

  String get _activeKey => '$_key.active';
  String _slotKey(int slot) => '$_key.slot$slot';

  Future<List<String>> load() async {
    final active = await _preferences.getInt(_activeKey);
    final preferred = active == 1 ? 1 : 0;
    final first = await _preferences.getStringList(_slotKey(preferred));
    if (first != null) return List.unmodifiable(first);

    final fallback = await _preferences.getStringList(_slotKey(1 - preferred));
    return fallback == null ? const <String>[] : List.unmodifiable(fallback);
  }

  Future<void> save(List<String> values) async {
    final active = await _preferences.getInt(_activeKey);
    final current = active == 1 ? 1 : 0;
    final target = 1 - current;
    await _preferences.setStringList(_slotKey(target), List<String>.from(values));
    await _preferences.setInt(_activeKey, target);
  }

  Future<void> clear() async => save(const <String>[]);
}
