import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:reproductor_iptv/core/domain/entities/channel.dart';
import 'package:reproductor_iptv/core/domain/entities/playlist.dart';
import 'package:reproductor_iptv/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playlists/repository/persistent_playlist_repository.dart';
import 'package:reproductor_iptv/core/playlists/repository/playlist_storage.dart';

class MemoryPlaylistStorage implements PlaylistStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<Map<String, String>> load() async => Map.of(values);

  @override
  Future<void> save(String id, String value) async {
    values[id] = value;
  }

  @override
  Future<void> remove(String id) async {
    values.remove(id);
  }

  @override
  Future<void> clear() async => values.clear();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Playlist playlist(String id, String name) => Playlist(
        id: id,
        name: name,
        sourceUri: Uri.parse('https://example.com/$id.m3u'),
        entries: [
          PlaylistEntry(
            id: '$id:channel',
            channel: Channel(
              id: '$id:channel',
              displayName: name,
            ),
            sources: [
              StreamSource(
                id: '$id:source',
                url: Uri.parse('https://example.com/$id.m3u8'),
              ),
            ],
          ),
        ],
      );

  test('keeps multiple playlists independently in app storage', () async {
    final storage = MemoryPlaylistStorage();
    final repository = PersistentPlaylistRepository(storage: storage);

    await repository.upsert(playlist('one', 'Uno'));
    await repository.upsert(playlist('two', 'Dos'));

    expect(repository.playlists.map((p) => p.id),
        containsAll(<String>['one', 'two']));
    expect(storage.values.length, 2);

    await repository.remove('one');

    expect(repository.getById('one'), isNull);
    expect(repository.getById('two'), isNotNull);
    expect(storage.values.keys, contains('two'));
  });

  test('restores playlists and their URL after a new repository instance',
      () async {
    final storage = MemoryPlaylistStorage();
    final first = PersistentPlaylistRepository(storage: storage);
    await first.upsert(playlist('one', 'Uno'));

    final second = PersistentPlaylistRepository(storage: storage);
    await second.load();

    expect(second.getById('one')?.name, 'Uno');
    expect(
      second.getById('one')?.sourceUri,
      Uri.parse('https://example.com/one.m3u'),
    );
  });

  test('migrates the legacy SharedPreferences playlist payload', () async {
    final preferences = SharedPreferencesAsync();
    final storage = MemoryPlaylistStorage();
    final legacy = playlist('legacy', 'Lista antigua');
    final raw = jsonEncode({
      'id': legacy.id,
      'name': legacy.name,
      'sourceUri': legacy.sourceUri.toString(),
      'rawContentHash': null,
      'updatedAt': null,
      'entries': [
        {
          'id': legacy.entries.first.id,
          'channel': {
            'id': legacy.entries.first.channel.id,
            'displayName': legacy.entries.first.channel.displayName,
            'tvgId': null,
            'country': null,
            'language': null,
          },
          'category': null,
          'logoUrl': null,
          'sources': [
            {
              'id': legacy.entries.first.sources.first.id,
              'url': legacy.entries.first.sources.first.url.toString(),
              'userAgent': null,
              'headers': <String, String>{},
            },
          ],
        },
      ],
    });
    await preferences.setStringList('playlists.v1', [raw]);

    final repository = PersistentPlaylistRepository(
      preferences: preferences,
      storage: storage,
    );
    await repository.load();

    expect(repository.getById('legacy')?.sourceUri,
        Uri.parse('https://example.com/legacy.m3u'));
    expect(storage.values, contains('legacy'));
    expect(await preferences.getStringList('playlists.v1'), isNull);
  });
}
