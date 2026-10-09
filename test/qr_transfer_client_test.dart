import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/transfer/qr_transfer_client.dart';

void main() {
  const privateToken = '0123456789abcdefghijklmn';

  test('rejects a public destination before sending any playlist', () async {
    await expectLater(
      QrTransferClient.sendPlaylist(
        sessionUrl: Uri.parse(
          'https://example.com:443/?token=$privateToken',
        ),
        content: '#EXTM3U\n',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects an empty playlist before opening a connection', () async {
    await expectLater(
      QrTransferClient.sendPlaylist(
        sessionUrl: Uri.parse(
          'http://192.168.1.20:43210/?token=$privateToken',
        ),
        content: '',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a playlist exceeding the transfer size limit', () async {
    await expectLater(
      QrTransferClient.sendPlaylist(
        sessionUrl: Uri.parse(
          'http://192.168.1.20:43210/?token=$privateToken',
        ),
        content: 'x' * (QrTransferClient.maxPlaylistBytes + 1),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
