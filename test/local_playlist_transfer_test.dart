import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:reproductor_iptv/core/transfer/local_playlist_transfer_server.dart';

void main() {
  test('accepts one authenticated playlist upload over LAN server', () async {
    String? received;
    final server = LocalPlaylistTransferServer(
      ttl: const Duration(seconds: 10),
      maxUploadBytes: 1024 * 1024,
    );

    final session = await server.start(
      onPlaylistUploaded: (content) async {
        received = content;
      },
    );
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: session.serverPort,
      path: '/upload',
      queryParameters: {'token': session.token},
    );
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.text;
    request.write(
      '#EXTM3U\n'
      '#EXTINF:-1,Demo\n'
      'https://example.com/live.m3u8\n',
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(body, contains('Playlist recibida'));
    expect(received, contains('#EXTM3U'));
  });

  test('rejects an invalid transfer token', () async {
    final server = LocalPlaylistTransferServer(
      ttl: const Duration(seconds: 10),
    );
    final session = await server.start(
      onPlaylistUploaded: (_) async {},
    );
    addTearDown(server.stop);

    final client = HttpClient();
    addTearDown(client.close);

    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: session.serverPort,
      path: '/',
      queryParameters: {'token': 'incorrect'},
    );
    final response = await (await client.getUrl(uri)).close();

    expect(response.statusCode, HttpStatus.unauthorized);
  });
}
