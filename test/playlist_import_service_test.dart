import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reproductor_iptv/core/playlists/importer/playlist_import_service.dart';

void main() {
  test('imports a remote M3U and keeps its source URL', () async {
    final client = MockClient((request) async {
      expect(request.url, Uri.parse('https://example.com/list.m3u'));
      return http.Response(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="demo",Demo\n'
        'https://example.com/demo.m3u8\n',
        200,
        headers: {'content-type': 'application/vnd.apple.mpegurl'},
      );
    });

    final service = PlaylistImportService(
      client: client,
      timeout: const Duration(seconds: 1),
    );
    addTearDown(service.dispose);

    final result = await service.importRemote(
      uri: Uri.parse('https://example.com/list.m3u'),
      playlistId: 'remote',
      name: 'Remota',
    );

    expect(result.playlist.entries, hasLength(1));
    expect(result.playlist.sourceUri,
        Uri.parse('https://example.com/list.m3u'));
    expect(result.replaced, isTrue);
  });


  test('imports text asynchronously and promotes the parsed playlist', () async {
    final service = PlaylistImportService();
    addTearDown(service.dispose);

    final result = await service.importText(
      text: '#EXTM3U\n'
          '#EXTINF:-1 tvg-id="demo" group-title="Noticias",Demo\n'
          'https://example.com/demo.m3u8\n',
      playlistId: 'text',
      name: 'Texto',
    );

    expect(result.playlist.id, 'text');
    expect(result.playlist.name, 'Texto');
    expect(result.playlist.entries, hasLength(1));
    expect(result.playlist.entries.single.channel.displayName, 'Demo');
    expect(result.playlist.entries.single.category, 'Noticias');
    expect(result.replaced, isTrue);
  });

  test('rejects redirect from playlist URL to private network', () async {
    final client = MockClient((request) async {
      return http.Response(
        '',
        302,
        headers: {'location': 'http://127.0.0.1/private.m3u'},
      );
    });

    final service = PlaylistImportService(client: client);
    addTearDown(service.dispose);

    expect(
      () => service.importRemote(
        uri: Uri.parse('https://example.com/list.m3u'),
        playlistId: 'remote',
        name: 'Remota',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
