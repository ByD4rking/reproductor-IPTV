import 'dart:convert';

import 'package:http/http.dart' as http;

import 'qr_transfer_payload.dart';

class QrTransferClient {
  const QrTransferClient._();

  static const int maxPlaylistBytes = 64 * 1024 * 1024;
  static const Duration requestTimeout = Duration(seconds: 20);

  static Future<int> sendPlaylist({
    required Uri sessionUrl,
    required String content,
  }) async {
    if (!QrTransferPayload.isValidSessionUri(sessionUrl)) {
      throw const FormatException(
        'La sesión QR debe apuntar a una TV en la red privada y contener un token válido.',
      );
    }

    final body = utf8.encode(content);
    if (body.isEmpty || body.length > maxPlaylistBytes) {
      throw const FormatException(
        'La playlist está vacía o supera el límite de transferencia de 64 MB.',
      );
    }

    final upload = sessionUrl.replace(path: '/upload');
    final request = http.Request('POST', upload)
      ..followRedirects = false
      ..headers['Content-Type'] = 'text/plain; charset=UTF-8'
      ..bodyBytes = body;

    final streamed = await http.Client()
        .send(request)
        .timeout(requestTimeout);
    final response = await http.Response.fromStream(streamed)
        .timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'La TV rechazó la transferencia (${response.statusCode}).',
      );
    }
    return response.statusCode;
  }
}
