import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/transfer/qr_transfer_payload.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  Future<void> _handle(String? value) async {
    if (_handled || value == null || value.trim().isEmpty) return;
    final payload = QrTransferPayload.tryParse(value.trim());
    if (payload == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR no reconocido por Reproductor IPTV.')),
        );
      }
      return;
    }

    _handled = true;
    await _controller.stop();
    if (!mounted) return;

    final action = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TV encontrada'),
        content: const Text(
          'Se encontró una sesión temporal de transferencia. '
          'La conexión es local y expira automáticamente. '
          '¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (action == true && mounted) {
      Navigator.of(context).pop(payload);
    } else if (mounted) {
      _handled = false;
      await _controller.start();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular TV por QR'),
        actions: [
          IconButton(
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                _handle(barcode.rawValue);
                if (_handled) break;
              }
            },
          ),
          Center(
            child: Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                border: Border.all(width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Apunta la cámara al QR que muestra tu TV o TV Box. '
                  'Ambos dispositivos deben estar en la misma red local.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
