import 'dart:io';

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
    try {
      final addresses = await InternetAddress.lookup(uri.host);
      if (addresses.isEmpty) return false;
      return addresses.every((address) => !_isBlockedAddress(address));
    } on SocketException {
      return false;
    }
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
    final address = InternetAddress.tryParse(value);
    return address != null && _isBlockedAddress(address);
  }

  static bool _isBlockedAddress(InternetAddress address) {
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4 && bytes.length == 4) {
      return _isBlockedIpv4(bytes);
    }
    if (address.type == InternetAddressType.IPv6 && bytes.length == 16) {
      final first = bytes[0];
      final second = bytes[1];
      final isLoopback = bytes.every((b) => b == 0) && bytes.last == 1;
      final isUnspecified = bytes.every((b) => b == 0);
      final isLinkLocal = first == 0xfe && (second & 0xc0) == 0x80;
      final isUniqueLocal = (first & 0xfe) == 0xfc;
      final isMulticast = first == 0xff;
      final isIpv4Mapped = bytes.sublist(0, 10).every((b) => b == 0) &&
          bytes[10] == 0xff &&
          bytes[11] == 0xff;
      final isIpv4Compatible = bytes.sublist(0, 12).every((b) => b == 0);

      if (isIpv4Mapped || isIpv4Compatible) {
        return _isBlockedIpv4(bytes.sublist(12));
      }

      return isLoopback ||
          isUnspecified ||
          isLinkLocal ||
          isUniqueLocal ||
          isMulticast;
    }
    return false;
  }

  static bool _isBlockedIpv4(List<int> bytes) {
    if (bytes.length != 4) return true;
    final a = bytes[0];
    final b = bytes[1];
    final c = bytes[2];

    return a == 0 ||
        a == 10 ||
        a == 127 ||
        (a == 100 && b >= 64 && b <= 127) ||
        (a == 169 && b == 254) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 0 && c == 0) ||
        (a == 192 && b == 0 && c == 2) ||
        (a == 192 && b == 168) ||
        (a == 198 && b >= 18 && b <= 19) ||
        (a == 198 && b == 51 && c == 100) ||
        (a == 203 && b == 0 && c == 113) ||
        a >= 224;
  }
}
