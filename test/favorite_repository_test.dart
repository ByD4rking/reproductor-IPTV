import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:reproductor_iptv/core/domain/entities/favorite.dart';
import 'package:reproductor_iptv/core/favorites/favorite_repository.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('stores favorites independently for different playlists', () async {
    final repository = FavoriteRepository();
    await repository.setFavorite(const Favorite(
      channelId: 'same-channel',
      preferredPlaylistId: 'playlist-one',
    ));
    await repository.setFavorite(const Favorite(
      channelId: 'same-channel',
      preferredPlaylistId: 'playlist-two',
    ));

    final favorites = await FavoriteRepository().load();
    expect(favorites, hasLength(2));
    expect(
      favorites.map((favorite) => favorite.preferredPlaylistId).toSet(),
      {'playlist-one', 'playlist-two'},
    );
  });

  test('concurrent writes retain every favorite', () async {
    final repository = FavoriteRepository();
    await Future.wait([
      repository.setFavorite(const Favorite(
        channelId: 'news',
        preferredPlaylistId: 'playlist-one',
      )),
      repository.setFavorite(const Favorite(
        channelId: 'sports',
        preferredPlaylistId: 'playlist-one',
      )),
      repository.setFavorite(const Favorite(
        channelId: 'movies',
        preferredPlaylistId: 'playlist-two',
      )),
    ]);

    final favorites = await FavoriteRepository().load();
    expect(
      favorites.map((favorite) => favorite.channelId).toSet(),
      {'news', 'sports', 'movies'},
    );
  });

  test('removing a favorite affects only the requested playlist', () async {
    final repository = FavoriteRepository();
    await repository.setFavorite(const Favorite(
      channelId: 'same-channel',
      preferredPlaylistId: 'playlist-one',
    ));
    await repository.setFavorite(const Favorite(
      channelId: 'same-channel',
      preferredPlaylistId: 'playlist-two',
    ));

    await repository.remove('same-channel', playlistId: 'playlist-one');
    final favorites = await repository.load();

    expect(favorites, hasLength(1));
    expect(favorites.single.preferredPlaylistId, 'playlist-two');
  });

  test('rejects an empty channel identifier', () async {
    await expectLater(
      FavoriteRepository().setFavorite(const Favorite(channelId: '  ')),
      throwsA(isA<FormatException>()),
    );
  });
}
