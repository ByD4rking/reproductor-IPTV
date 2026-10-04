import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:reproductor_iptv/core/playlists/xtream/xtream_import_service.dart';

void main() {
  test('imports Xtream live channels and maps categories', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'example.com');
      expect(request.url.queryParameters['username'], 'demo');
      expect(request.url.queryParameters['password'], 'secret');

      switch (request.url.queryParameters['action']) {
        case 'get_live_categories':
          return http.Response(
            '[{"category_id":"1","category_name":"Noticias"}]',
            200,
          );
        case 'get_live_streams':
          return http.Response(
            '[{"stream_id":42,"name":"Canal Demo","category_id":"1","epg_channel_id":"demo.tv","stream_icon":"https://example.com/logo.png"}]',
            200,
          );
        default:
          return http.Response('', 400);
      }
    });

    final service = XtreamImportService(client: client);
    addTearDown(service.dispose);

    final playlist = await service.importLiveChannels(
      server: Uri.parse('https://example.com/player_api.php'),
      username: 'demo',
      password: 'secret',
    );

    expect(playlist.entries, hasLength(1));
    expect(playlist.entries.single.channel.displayName, 'Canal Demo');
    expect(playlist.entries.single.channel.tvgId, 'demo.tv');
    expect(playlist.entries.single.category, 'Noticias');
    expect(
      playlist.entries.single.sources.single.url.toString(),
      contains('/live/demo/secret/42.m3u8'),
    );
    expect(playlist.sourceUri, Uri.parse('https://example.com/'));
  });

  test('rejects Xtream credentials when the server is unsafe', () async {
    final service = XtreamImportService(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    addTearDown(service.dispose);

    expect(
      () => service.importLiveChannels(
        server: Uri.parse('http://127.0.0.1:8080'),
        username: 'demo',
        password: 'secret',
      ),
      throwsA(isA<XtreamException>()),
    );
  });
}
