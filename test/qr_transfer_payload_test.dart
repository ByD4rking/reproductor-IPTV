import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/transfer/qr_transfer_payload.dart';

void main() {
  const token = '0123456789abcdefghijklmn';

  test('accepts a valid private-LAN transfer session', () {
    final payload = QrTransferPayload(
      url: Uri.parse('http://192.168.1.20:43210/?token=$token'),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    expect(QrTransferPayload.tryParse(payload.encode()), isNotNull);
  });

  test('rejects public hosts to prevent playlist exfiltration', () {
    final payload = QrTransferPayload(
      url: Uri.parse('https://example.com:443/?token=$token'),
    );

    expect(QrTransferPayload.tryParse(payload.encode()), isNull);
  });

  test('rejects QR URLs without token or with credentials', () {
    final missingToken = QrTransferPayload(
      url: Uri.parse('http://192.168.1.20:43210/'),
    );
    final credentials = QrTransferPayload(
      url: Uri.parse('http://user:pass@192.168.1.20:43210/?token=$token'),
    );

    expect(QrTransferPayload.tryParse(missingToken.encode()), isNull);
    expect(QrTransferPayload.tryParse(credentials.encode()), isNull);
  });

  test('rejects expired transfer sessions', () {
    final payload = QrTransferPayload(
      url: Uri.parse('http://10.0.0.5:43210/?token=$token'),
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );

    expect(QrTransferPayload.tryParse(payload.encode()), isNull);
  });

  test('rejects loopback and link-local destinations', () {
    for (final host in ['127.0.0.1', '169.254.10.2', '8.8.8.8']) {
      final payload = QrTransferPayload(
        url: Uri.parse('http://$host:43210/?token=$token'),
      );
      expect(QrTransferPayload.tryParse(payload.encode()), isNull, reason: host);
    }
  });
}
