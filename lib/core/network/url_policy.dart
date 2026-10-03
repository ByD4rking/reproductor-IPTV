class UrlPolicy {
  const UrlPolicy({this.maxRedirects = 5, this.maxUrlLength = 8192});

  final int maxRedirects;
  final int maxUrlLength;

  bool accepts(Uri uri) {
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return false;
    if (uri.host.isEmpty || uri.host.length > 253) return false;
    if (uri.toString().length > maxUrlLength) return false;
    if (uri.userInfo.isNotEmpty) return false;
    return true;
  }

  bool acceptsRedirectCount(int count) => count >= 0 && count <= maxRedirects;
}
