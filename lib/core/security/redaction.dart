class SecretRedactor {
  const SecretRedactor();

  String url(Uri uri) {
    final rawQuery = uri.query;
    if (rawQuery.isEmpty) return uri.toString();

    final redactedQuery = rawQuery.split('&').map((part) {
      final separator = part.indexOf('=');
      final rawKey = separator < 0 ? part : part.substring(0, separator);
      final key = Uri.decodeQueryComponent(rawKey);
      if (!_sensitive(key)) return part;
      return '$rawKey=[REDACTED]';
    }).join('&');

    final base = uri.replace(query: null).toString();
    return '$base?$redactedQuery';
  }

  Map<String, String> headers(Map<String, String> input) {
    return Map.unmodifiable({
      for (final entry in input.entries)
        entry.key: _sensitiveHeader(entry.key)
            ? '[REDACTED]'
            : entry.value,
    });
  }

  bool _sensitiveHeader(String key) {
    final k = key.toLowerCase();
    return k == 'authorization' ||
        k == 'proxy-authorization' ||
        k == 'cookie' ||
        k == 'set-cookie' ||
        _sensitive(k);
  }

  bool _sensitive(String key) {
    final k = key.toLowerCase();
    return k.contains('token') ||
        k.contains('password') ||
        k.contains('secret') ||
        k.contains('auth') ||
        k.contains('credential') ||
        k == 'key';
  }
}
