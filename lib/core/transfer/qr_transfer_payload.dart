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
      if (encoded.isEmpty || encoded.length > 8192) return null;
      final padded = encoded.padRight(
        encoded.length + ((4 - encoded.length % 4) % 4),
        '=',
      );
      final json = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (json is! Map) return null;
      if (json['type'] != 'iptv-transfer') return null;
      final version = json['v'];
      if (version is! int || version != 1) return null;
      final rawUrl = json['url'];
      if (rawUrl is! String || rawUrl.length > 2048) return null;
      final url = Uri.tryParse(rawUrl);
      if (url == null || (url.scheme != 'http' && url.scheme != 'https')) {
        return null;
      }

      // A transfer QR must point to the temporary TV server on the local
      // network. Do not let a crafted QR trick the app into POSTing playlist
      // contents (which may contain private URLs) to an arbitrary public host.
      if (url.userInfo.isNotEmpty ||
          url.host.isEmpty ||
          url.port < 1 ||
          url.port > 65535 ||
          url.path != '/' ||
          !_isPrivateIpv4(url.host) ||
          url.queryParameters.length != 1 ||
          url.queryParameters['token'] == null ||
          url.queryParameters['token']!.length < 24 ||
          url.queryParameters['token']!.length > 128 ||
          url.fragment.isNotEmpty) {
        return null;
      }

      final exp = json['exp'];
      if (exp != null && exp is! int) return null;
      final expiresAt = exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp, isUtc: true)
          : null;
      if (expiresAt != null && !expiresAt.isAfter(DateTime.now().toUtc())) {
        return null;
      }
      return QrTransferPayload(url: url, expiresAt: expiresAt, version: version);
    } catch (_) {
      return null;
    }
  }

  static bool _isPrivateIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255 || part != value.toString()) {
        return false;
      }
      octets.add(value);
    }
    final a = octets[0];
    final b = octets[1];
    return a == 10 ||
        a == 192 && b == 168 ||
        a == 172 && b >= 16 && b <= 31;
  }
}
