class LocalTransferSession {
  const LocalTransferSession({
    required this.serverPort,
    required this.token,
    required this.expiresAt,
    required this.addresses,
  });

  final int serverPort;
  final String token;
  final DateTime expiresAt;
  final List<String> addresses;
}

class LocalPlaylistTransferServer {
  LocalPlaylistTransferServer({
    this.ttl = const Duration(minutes: 10),
    this.maxUploadBytes = 64 * 1024 * 1024,
  });

  final Duration ttl;
  final int maxUploadBytes;

  Future<LocalTransferSession> start({
    required Future<void> Function(String content) onPlaylistUploaded,
  }) {
    throw UnsupportedError(
      'La transferencia LAN directa todavía requiere la API de red del navegador.',
    );
  }

  Future<void> stop() async {}
}
