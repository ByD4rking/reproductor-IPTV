import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../playlists/m3u/m3u_parser.dart';

class LocalTransferSession {
  const LocalTransferSession({
    required this.serverPort,
    required this.token,
    required this.expiresAt,
    required this.addresses,
  });

  final int serverPort;
  final String token;
  final DateTime expiresAt;
  final List<String> addresses;
}

class LocalPlaylistTransferServer {
  LocalPlaylistTransferServer({
    this.ttl = const Duration(minutes: 10),
    this.maxUploadBytes = 64 * 1024 * 1024,
  });

  final Duration ttl;
  final int maxUploadBytes;
  HttpServer? _server;
  Timer? _expiryTimer;
  String? _token;
  bool _used = false;
  bool _uploading = false;

  Future<LocalTransferSession> start({
    required Future<void> Function(String content) onPlaylistUploaded,
  }) async {
    await stop();

    _token = _randomToken();
    _used = false;
    _uploading = false;
    final token = _token!;
    final expiresAt = DateTime.now().add(ttl);
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _expiryTimer = Timer(ttl, stop);

    unawaited(
      () async {
        await for (final request in server) {
          await _handle(request, token, expiresAt, onPlaylistUploaded);
        }
      }(),
    );

    final addresses = <String>[];
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    )) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) addresses.add(address.address);
      }
    }

    return LocalTransferSession(
      serverPort: server.port,
      token: token,
      expiresAt: expiresAt,
      addresses: List.unmodifiable(addresses.toSet()),
    );
  }

  Future<void> _handle(
    HttpRequest request,
    String token,
    DateTime expiresAt,
    Future<void> Function(String content) onPlaylistUploaded,
  ) async {
    try {
      if (DateTime.now().isAfter(expiresAt)) {
        request.response
          ..statusCode = HttpStatus.gone
          ..write('Sesión expirada');
        await request.response.close();
        return;
      }
      if (request.uri.queryParameters['token'] != token) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..write('Token inválido');
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/') {
        request.response
          ..headers.contentType = ContentType.html
          ..write(_page(token, expiresAt));
        await request.response.close();
        return;
      }

      if (request.method != 'POST' || request.uri.path != '/upload') {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Ruta no encontrada');
        await request.response.close();
        return;
      }
      if (_used || _uploading) {
        request.response
          ..statusCode = HttpStatus.conflict
          ..write(_used ? 'La sesión ya fue utilizada' : 'La sesión está procesando otra transferencia');
        await request.response.close();
        return;
      }

      _uploading = true;
      final contentLength = request.contentLength;
      if (contentLength > maxUploadBytes) {
        request.response
          ..statusCode = HttpStatus.requestEntityTooLarge
          ..write('La playlist supera el límite permitido');
        await request.response.close();
        return;
      }

      final bytes = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in request) {
        total += chunk.length;
        if (total > maxUploadBytes) {
          request.response
            ..statusCode = HttpStatus.requestEntityTooLarge
            ..write('La playlist supera el límite permitido');
          await request.response.close();
          _uploading = false;
          return;
        }
        bytes.add(chunk);
      }

      final content = utf8.decode(bytes.takeBytes(), allowMalformed: true);
      final playlist = const M3uParser().parse(
        content,
        playlistId: 'transfer',
        name: 'Playlist transferida',
      );
      await onPlaylistUploaded(content);
      _used = true;

      request.response
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><html><body><h2>Playlist recibida</h2>'
          '<p>Canales: ${playlist.entries.length}</p>'
          '<p>Ya puedes cerrar esta ventana.</p></body></html>',
        );
      await request.response.close();
      _uploading = false;
      await stop();
    } catch (error) {
      _uploading = false;
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.text
        ..write('No se pudo importar la playlist: $error');
      await request.response.close();
    }
  }

  String _page(String token, DateTime expiresAt) {
    final safeToken = htmlEscape.convert(token);
    final iso = htmlEscape.convert(expiresAt.toLocal().toIso8601String());
    return '''<!doctype html>
<html lang="es"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Transferir playlist IPTV</title>
<body style="font-family:Arial,sans-serif;max-width:720px;margin:40px auto;padding:20px">
<h2>Transferir playlist IPTV</h2>
<p>Selecciona un archivo M3U/M3U8/TXT. La sesión vence el <b>$iso</b> y solo acepta una transferencia.</p>
<input id="file" type="file" accept=".m3u,.m3u8,.txt">
<button id="send" disabled>Enviar</button>
<pre id="status"></pre>
<script>
const token = "$safeToken";
const file = document.getElementById('file');
const send = document.getElementById('send');
const status = document.getElementById('status');
file.onchange = () => { send.disabled = !file.files.length; };
send.onclick = async () => {
  const selected = file.files[0];
  send.disabled = true;
  status.textContent = 'Enviando...';
  try {
    const response = await fetch('/upload?token=' + encodeURIComponent(token), {
      method: 'POST',
      headers: {'Content-Type': 'text/plain;charset=UTF-8'},
      body: selected
    });
    status.textContent = await response.text();
  } catch (e) {
    status.textContent = 'Error de conexión: ' + e;
    send.disabled = false;
  }
};
</script></body></html>''';
  }

  String _randomToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<void> stop() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    final server = _server;
    _server = null;
    _token = null;
    if (server != null) {
      await server.close(force: true);
    }
  }
}
