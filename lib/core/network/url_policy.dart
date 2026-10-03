class UrlPolicy {
  const UrlPolicy({this.maxRedirects=5});
  final int maxRedirects;
  bool accepts(Uri uri) => uri.isScheme('http') || uri.isScheme('https');
  bool acceptsRedirectCount(int count) => count <= maxRedirects;
}
