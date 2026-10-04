import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/playlists/importer/playlist_import_service.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
import '../../core/playlists/repository/playlist_repository.dart';

class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({required this.repository, super.key});
  final PlaylistRepository repository;

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final _url = TextEditingController();
  final _name = TextEditingController(text: 'Mi playlist');
  final _text = TextEditingController();
  final _service = PlaylistImportService();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _text.dispose();
    _service.dispose();
    super.dispose();
  }

  String get _playlistName =>
      _name.text.trim().isEmpty ? 'Mi playlist' : _name.text.trim();

  Future<void> _importUrl() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null) {
      setState(() => _message = 'URL inválida');
      return;
    }
    await _run(() async {
      final result = await _service.importRemote(
        uri: uri,
        playlistId: 'playlist-${DateTime.now().microsecondsSinceEpoch}',
        name: _playlistName,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Importada desde URL: ${result.playlist.entries.length} canales');
      }
    });
  }

  Future<void> _importFile() async {
    await _run(() async {
      final file = await FilePicker.pickFile();
      if (file == null) return;

      final name = file.name;
      final lowerName = name.toLowerCase();
      final allowed = lowerName.endsWith('.m3u') ||
          lowerName.endsWith('.m3u8') ||
          lowerName.endsWith('.txt');
      if (!allowed) {
        throw const FormatException(
          'Selecciona una playlist M3U, M3U8 o TXT.',
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.length > const M3uParser().maxContentCharacters) {
        throw const FormatException('La playlist supera el límite permitido.');
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      final result = _service.importText(
        text: text,
        playlistId: 'playlist-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim().isEmpty
            ? name.replaceFirst(RegExp(r'\.[^.]+$'), '')
            : _playlistName,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Importada desde archivo: ${result.playlist.entries.length} canales');
      }
    });
  }

  Future<void> _importText() async {
    await _run(() async {
      final result = _service.importText(
        text: _text.text,
        playlistId: 'playlist-${DateTime.now().microsecondsSinceEpoch}',
        name: _playlistName,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Importada desde texto: ${result.playlist.entries.length} canales');
      }
    });
  }

  Future<void> _showTvTransferHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PC o teléfono → TV'),
        content: const Text(
          'En un Smart TV, el archivo que está en tu PC o teléfono no aparece '
          'automáticamente en la TV.\n\n'
          'La forma universal es poner la playlist en una URL HTTP/HTTPS '
          'accesible desde la TV y pegar esa URL en “Importar URL”.\n\n'
          'En Android TV / Google TV / Fire TV también puedes usar “Archivo '
          'local” para seleccionar una playlist desde almacenamiento, USB o '
          'un proveedor de archivos compatible.\n\n'
          'La transferencia directa PC/teléfono → LG webOS/Tizen mediante '
          'código/QR todavía requiere un canal de transferencia específico y '
          'no se debe fingir como implementado hasta probarlo en el televisor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } on UnsupportedError catch (error) {
      if (mounted) {
        setState(() => _message =
            'Este dispositivo no ofrece selector de archivos: $error');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Agregar playlist')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Elige cómo quieres cargar tu lista',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Puedes usar una URL, un archivo M3U/M3U8/TXT o pegar el contenido. '
              'Las listas importadas quedan guardadas en la biblioteca.',
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Importar desde URL'),
                subtitle: const Text('M3U/M3U8 por HTTP o HTTPS'),
                trailing: FilledButton(
                  onPressed: _busy ? null : _importUrl,
                  child: const Text('Cargar'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL M3U/M3U8',
                hintText: 'https://servidor/lista.m3u',
                prefixIcon: Icon(Icons.public),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Cargar archivo local'),
                subtitle: const Text('M3U, M3U8 o TXT desde el dispositivo'),
                trailing: FilledButton.icon(
                  onPressed: _busy ? null : _importFile,
                  icon: const Icon(Icons.file_open),
                  label: const Text('Abrir archivo'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Desde PC o teléfono'),
                subtitle: const Text(
                  'Cómo pasar una playlist a un Smart TV',
                ),
                trailing: OutlinedButton(
                  onPressed: _busy ? null : _showTvTransferHelp,
                  child: const Text('Ver opciones'),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Pegar contenido M3U',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'Contenido M3U',
                hintText: '#EXTM3U\n#EXTINF:-1,...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _importText,
              icon: const Icon(Icons.content_paste),
              label: const Text('Importar texto'),
            ),
            if (_busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_message != null) ...[
              const SizedBox(height: 18),
              SelectableText(_message!),
            ],
          ],
        ),
      );
}
