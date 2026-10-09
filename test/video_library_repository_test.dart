import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:reproductor_iptv/core/video/video_library_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('persists items and restores them from a new repository', () async {
    final first = VideoLibraryRepository();
    await first.upsert(VideoLibraryItem(
      id: 'one',
      title: 'Movie one',
      url: Uri.parse('https://media.example/movie.mp4'),
      category: 'Movies',
    ));

    final restored = await VideoLibraryRepository().load();
    expect(restored, hasLength(1));
    expect(restored.single.title, 'Movie one');
    expect(restored.single.category, 'Movies');
  });

  test('serializes concurrent additions without losing either item', () async {
    final repository = VideoLibraryRepository();
    await Future.wait([
      repository.upsert(VideoLibraryItem(
        id: 'one',
        title: 'One',
        url: Uri.parse('https://media.example/one.mp4'),
      )),
      repository.upsert(VideoLibraryItem(
        id: 'two',
        title: 'Two',
        url: Uri.parse('https://media.example/two.mp4'),
      )),
    ]);

    final restored = await VideoLibraryRepository().load();
    expect(restored.map((item) => item.id).toSet(), {'one', 'two'});
  });

  test('rejects malformed or non-HTTP media URLs', () {
    expect(
      VideoLibraryItem.fromJson({
        'id': 'bad',
        'title': 'Bad item',
        'url': 'file:///etc/passwd',
      }),
      isNull,
    );
    expect(
      VideoLibraryItem.fromJson({
        'id': 'blank',
        'title': ' ',
        'url': 'https://media.example/movie.mp4',
      }),
      isNull,
    );
  });
}
