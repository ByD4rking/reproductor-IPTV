import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:reproductor_iptv/core/playlists/organization/playlist_organization.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('persists custom folders and channel assignments per playlist', () async {
    final repository = PlaylistOrganizationRepository();
    final folder = await repository.createFolder('one', 'Mis deportes');
    await repository.moveEntry('one', 'channel-1', folder.id);

    final restored = await PlaylistOrganizationRepository().load('one');

    expect(restored.folders.single.name, 'Mis deportes');
    expect(restored.assignments['channel-1'], folder.id);
    expect(await repository.load('two'), isA<PlaylistOrganization>());
    expect((await repository.load('two')).folders, isEmpty);
  });

  test('sync adds M3U groups without overwriting custom folders', () async {
    final repository = PlaylistOrganizationRepository();
    final custom = await repository.createFolder('one', 'Mi carpeta');
    await repository.moveEntry('one', 'channel-1', custom.id);

    final synced = await repository.syncWithGroups(
      'one',
      ['Noticias', 'Deportes'],
    );

    expect(synced.folders.map((folder) => folder.name),
        containsAll(['Mi carpeta', 'Noticias', 'Deportes']));
    expect(synced.assignments['channel-1'], custom.id);
  });

  test('deleting a custom folder clears only its assignments', () async {
    final repository = PlaylistOrganizationRepository();
    final custom = await repository.createFolder('one', 'Temporal');
    await repository.moveEntry('one', 'a', custom.id);
    await repository.moveEntry('one', 'b', custom.id);

    await repository.deleteFolder('one', custom.id);
    final restored = await repository.load('one');

    expect(restored.folders, isEmpty);
    expect(restored.assignments, isEmpty);
  });

  test('original M3U groups cannot be deleted', () async {
    final repository = PlaylistOrganizationRepository();
    final synced = await repository.syncWithGroups('one', ['Noticias']);

    expect(
      () => repository.deleteFolder('one', synced.folders.single.id),
      throwsA(isA<StateError>()),
    );
  });

  test('reorders folders persistently', () async {
    final repository = PlaylistOrganizationRepository();
    final first = await repository.createFolder('one', 'A');
    final second = await repository.createFolder('one', 'B');

    await repository.reorder('one', second.id, -1);
    final restored = await repository.load('one');

    final ordered = [...restored.folders]
      ..sort((a, b) => a.order.compareTo(b.order));
    expect(ordered.map((folder) => folder.name), ['B', 'A']);
    expect(first.custom, isTrue);
  });
}
