import 'package:flutter_test/flutter_test.dart';

import 'package:reproductor_iptv/core/domain/entities/channel.dart';
import 'package:reproductor_iptv/core/domain/entities/playlist.dart';
import 'package:reproductor_iptv/core/domain/entities/stream_source.dart';
import 'package:reproductor_iptv/core/playlists/grouping/playlist_groups.dart';
import 'package:reproductor_iptv/core/playlists/m3u/m3u_parser.dart';

Playlist _playlist(String id, String name, List<PlaylistEntry> entries) =>
    Playlist(id: id, name: name, entries: entries);

PlaylistEntry _entry(String id, String category) => PlaylistEntry(
      id: id,
      channel: Channel(id: id, displayName: id),
      category: category,
      sources: [
        StreamSource(id: '$id:source', url: Uri.parse('https://example.com/$id')),
      ],
    );

void main() {
  test('M3U group-title and tvg-group become folder names', () {
    const parser = M3uParser();
    final playlist = parser.parse(
      '#EXTM3U\n'
      '#EXTINF:-1 group-title="Noticias",Canal 1\n'
      'https://example.com/one.m3u8\n'
      '#EXTINF:-1 tvg-group="Deportes",Canal 2\n'
      'https://example.com/two.m3u8\n',
    );

    final groups = PlaylistGroups.fromPlaylist(playlist);

    expect(groups.map((group) => group.name),
        containsAll(<String>['Noticias', 'Deportes']));
    expect(groups.firstWhere((group) => group.name == 'Noticias').count, 1);
    expect(groups.firstWhere((group) => group.name == 'Deportes').count, 1);
  });

  test('entries without a category go to a safe fallback folder', () {
    final playlist = _playlist(
      'one',
      'Lista 1',
      [
        _entry('news', ' Noticias '),
        PlaylistEntry(
          id: 'other',
          channel: const Channel(id: 'other', displayName: 'Other'),
          sources: [
            StreamSource(
                id: 'other:source', url: Uri.parse('https://example.com/other')),
          ],
        ),
      ],
    );

    final groups = PlaylistGroups.fromPlaylist(playlist);

    expect(groups.map((group) => group.name),
        containsAll(<String>['Noticias', 'Sin categoría']));
    expect(groups.firstWhere((group) => group.name == 'Noticias').count, 1);
    expect(
        groups.firstWhere((group) => group.name == 'Sin categoría').count, 1);
  });

  test('folder grouping is isolated per playlist', () {
    final first = PlaylistGroups.fromPlaylist(
      _playlist('one', 'Chile', [_entry('a', 'Nacional')]),
    );
    final second = PlaylistGroups.fromPlaylist(
      _playlist('two', 'Deportes', [_entry('b', 'Fútbol')]),
    );

    expect(first.map((group) => group.name), ['Nacional']);
    expect(second.map((group) => group.name), ['Fútbol']);
  });

  test('creates a favorites folder without changing original categories', () {
    final playlist = _playlist(
      'favorites',
      'Lista',
      [
        _entry('one', 'Noticias'),
        _entry('two', 'Deportes'),
      ],
    );

    final groups = PlaylistGroups.fromPlaylist(
      playlist,
      favoriteChannelIds: {'two'},
    );

    expect(groups.first.name, 'Favoritos');
    expect(groups.first.isFavorites, isTrue);
    expect(groups.first.entries.single.channel.id, 'two');
    expect(groups.any((group) => group.name == 'Noticias'), isTrue);
    expect(groups.any((group) => group.name == 'Deportes'), isTrue);
  });

  test('does not create an empty favorites folder', () {
    final playlist = _playlist(
      'no-favorites',
      'Lista',
      [_entry('one', 'Noticias')],
    );

    final groups = PlaylistGroups.fromPlaylist(playlist);

    expect(groups.any((group) => group.name == 'Favoritos'), isFalse);
  });

}
