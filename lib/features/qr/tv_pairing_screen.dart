import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/transfer/qr_transfer_payload.dart';
import '../../core/transfer/local_playlist_transfer_server.dart';

class TvPairingScreen extends StatefulWidget {
  const TvPairingScreen({super.key, this.onPlaylistUploaded});

  final Future<void> Function(String content)? onPlaylistUploaded;

  @override
  State<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends State<TvPairingScreen> {
  late final LocalPlaylistTransferServer _server;
  LocalTransferSession? _session;
  String? _message;

  @override
  void initState() {
    super.initState();
    _server = LocalPlaylistTransferServer();
    _start();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final session = await _server.start(
        onPlaylistUploaded: widget.onPlaylistUploaded ?? (_) async {},
      );
      if (mounted) setState(() => _session = session);
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo iniciar la vinculación: ' + error.toString());
    }
  }

  Future<void> _restart() async {
    await _server.stop();
    if (mounted) setState(() => _session = null);
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final url = session == null || session.addresses.isEmpty
        ? null
        : Uri.parse(
            'http://' + session.addresses.first + ':' +
            session.serverPort.toString() + '/?token=' +
            Uri.encodeQueryComponent(session.token),
          );
    final payload = url == null
        ? null
        : QrTransferPayload(url: url, expiresAt: session.expiresAt).encode();

    return Scaffold(
      appBar: AppBar(title: const Text('Vincular TV / TV Box')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(32),
            children: [
              const Icon(Icons.devices_other, size: 64),
              const SizedBox(height: 12),
              Text(
                'Vincular contenido con Android / tablet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'La TV crea una sesión local temporal. Escanea este QR desde '
                'Android o tablet para transferir una playlist a este equipo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (payload != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: QrImageView(
                      data: payload,
                      size: 360,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      semanticsLabel: 'QR para vincular Reproductor IPTV',
                    ),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              if (session != null) ...[
                Text(
                  'Código temporal activo durante 10 minutos.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Red local: ' +
                  (session.addresses.isEmpty ? 'no detectada' : session.addresses.join(', ')),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generar otro QR'),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 16),
                SelectableText(_message!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
