class UrlPolicy {
  const UrlPolicy({this.maxRedirects = 5, this.maxUrlLength = 8192});

  final int maxRedirects;
  final int maxUrlLength;

  bool accepts(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
    if (uri.host.isEmpty || uri.host.length > 253) return false;
    if (uri.toString().length > maxUrlLength) return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (_isBlockedHost(uri.host)) return false;
    return !_isBlockedLiteralIp(uri.host);
  }

  Future<bool> acceptsResolved(Uri uri,
      {bool allowPrivateNetwork = false}) async {
    if (!accepts(uri)) return false;
    if (allowPrivateNetwork) return true;
    // Web cannot perform a trustworthy DNS resolution from Dart, so reject
    // literal/private destinations before the browser request is made.
    return !_isBlockedLiteralIp(uri.host);
  }

  bool acceptsRedirectCount(int count) => count >= 0 && count <= maxRedirects;

  static bool _isBlockedHost(String host) {
    final normalized = host.toLowerCase().replaceFirst(RegExp(r'\\.$'), '');
    return normalized == 'localhost' ||
        normalized == 'localhost.localdomain' ||
        normalized.endsWith('.localhost') ||
        normalized.endsWith('.local') ||
        normalized == 'metadata.google.internal' ||
        normalized == 'metadata' ||
        normalized == 'instance-data.ec2.internal';
  }

  static bool _isBlockedLiteralIp(String host) {
    final value = host.replaceAll('[', '').replaceAll(']', '');
    final parts = value.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      final octets = parts.map(int.parse).toList(growable: false);
      if (octets.any((v) => v < 0 || v > 255)) return true;
      final a = octets[0], b = octets[1];
      return a == 0 ||
          a == 10 ||
          a == 127 ||
          (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) ||
          (a == 192 && b == 168) ||
          (a >= 224);
    }
    return value.contains(':') && _isBlockedIpv6(value);
  }

  static bool _isBlockedIpv6(String value) {
    final normalized = value.toLowerCase();
    return normalized == '::' ||
        normalized == '::1' ||
        normalized.startsWith('fe80:') ||
        normalized.startsWith('fc') ||
        normalized.startsWith('fd') ||
        normalized.startsWith('ff');
  }
}
