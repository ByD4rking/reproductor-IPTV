class SecretRedactor {
  const SecretRedactor();

  String url(Uri uri) {
    if (uri.queryParameters.isEmpty) return uri.toString();

    final safe = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      safe[key] = _sensitive(key) ? '[REDACTED]' : value;
    });
    return uri.replace(queryParameters: safe).toString();
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
