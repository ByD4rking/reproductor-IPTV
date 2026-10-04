import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/storage/atomic_string_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();

  test('keeps the previous committed snapshot until the new slot is selected',
      () async {
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
