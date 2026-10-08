import 'dart:convert';

class QrTransferPayload {
  const QrTransferPayload({
    required this.url,
    this.expiresAt,
    this.version = 1,
  });

  final Uri url;
  final DateTime? expiresAt;
  final int version;

  String encode() {
    final data = <String, dynamic>{
      'v': version,
      'type': 'iptv-transfer',
      'url': url.toString(),
      if (expiresAt != null) 'exp': expiresAt!.toUtc().millisecondsSinceEpoch,
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    return 'iptvqr:' + encoded;
  }

  static QrTransferPayload? tryParse(String raw) {
    try {
      if (!raw.startsWith('iptvqr:')) return null;
      final encoded = raw.substring('iptvqr:'.length);
      final padded = encoded.padRight(
        encoded.length + ((4 - encoded.length % 4) % 4),
        '=',
      );
      final json = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (json is! Map) return null;
      if (json['type'] != 'iptv-transfer') return null;
      final version = json['v'];
      if (version is! int || version != 1) return null;
      final url = Uri.tryParse(json['url'] as String? ?? '');
      if (url == null || (url.scheme != 'http' && url.scheme != 'https')) {
        return null;
      }
      final exp = json['exp'];
      final expiresAt = exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp, isUtc: true)
          : null;
      if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
        return null;
      }
      return QrTransferPayload(url: url, expiresAt: expiresAt, version: version);
    } catch (_) {
      return null;
    }
  }
}
