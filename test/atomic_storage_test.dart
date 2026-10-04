import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/storage/atomic_string_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('keeps the previous committed snapshot until the new slot is selected', () async {
    final preferences = SharedPreferencesAsync();
    final store = AtomicStringListStore(
      preferences: preferences,
      key: 'test.atomic',
    );

    await store.save(const ['one', 'two']);
    expect(await store.load(), ['one', 'two']);

    await store.save(const ['three']);
    expect(await store.load(), ['three']);
  });
}
