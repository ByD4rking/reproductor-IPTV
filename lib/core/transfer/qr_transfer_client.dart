import 'dart:convert';
import 'package:http/http.dart' as http;

class QrTransferClient {
  const QrTransferClient._();
  static Future<int> sendPlaylist({required Uri sessionUrl, required String content}) async {
    final upload = sessionUrl.replace(path: sessionUrl.path == '/' ? '/upload' : sessionUrl.path + '/upload');
    final response = await http.post(upload, headers: const {'Content-Type': 'text/plain; charset=UTF-8'}, body: utf8.encode(content));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('La TV rechazó la transferencia (' + response.statusCode.toString() + ').');
    }
    return response.statusCode;
  }
}
