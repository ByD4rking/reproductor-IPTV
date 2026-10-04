import 'package:flutter/material.dart';

import '../../core/transfer/local_playlist_transfer_server.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
import '../../core/playlists/repository/playlist_repository.dart';

class LocalPlaylistTransferScreen extends StatefulWidget {
  const LocalPlaylistTransferScreen({
    required this.repository,
    super.key,
  });

  final PlaylistRepository repository;

  @override
  State<LocalPlaylistTransferScreen> createState() =>
      _LocalPlaylistTransferScreenState();
}

class _LocalPlaylistTransferScreenState
    extends State<LocalPlaylistTransferScreen> {
  late final LocalPlaylistTransferServer _server;
  LocalTransferSession? _session;
  String? _message;

  @override
  void initState() {
    super.initState();
    _server = LocalPlaylistTransferServer();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _message = null);
    try {
      final session = await _server.start(
        onPlaylistUploaded: (content) async {
          final playlist = const M3uParser().parse(
            content,
            playlistId:
                'transfer-${DateTime.now().microsecondsSinceEpoch}',
            name: 'Playlist transferida',
          );
          await widget.repository.upsert(playlist);
        },
      );
      if (mounted) setState(() => _session = session);
    } catch (error) {
      if (mounted) {
        setState(() => _message =
            'No se pudo iniciar la transferencia local: $error');
      }
    }
  }

  Future<void> _stop() async {
    await _server.stop();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir playlist a este TV')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.wifi_tethering, size: 72),
          const SizedBox(height: 12),
          Text(
            'Recibir desde PC o teléfono',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Este dispositivo abre temporalmente un servidor local. '
            'Abre la dirección mostrada desde el teléfono o PC que tiene tu archivo '
            'M3U y envía una sola playlist.',
          ),
          const SizedBox(height: 20),
          if (session == null)
            FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.wifi),
              label: const Text('Iniciar transferencia'),
            )
          else ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Sesión protegida y temporal'),
                subtitle: Text(
                  'El enlace usa un token aleatorio, vence automáticamente '
                  'y solo admite una transferencia.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...session.addresses.map(
              (address) => SelectableText(
                'http://$address:${session.serverPort}/?token=${session.token}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (session.addresses.isEmpty)
              const SelectableText(
                'No se detectó una dirección IPv4 de la red local. '
                'Comprueba que el TV esté conectado a la red.',
              ),
            const SizedBox(height: 16),
            Text(
              'Expira: ${session.expiresAt.toLocal()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Cerrar transferencia'),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            SelectableText(_message!),
          ],
        ],
      ),
    );
  }
}
