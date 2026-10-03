import 'package:flutter/material.dart';

import '../../core/playlists/importer/playlist_import_service.dart';
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
    super.dispose();
  }

  Future<void> _importUrl() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null) {
      setState(() => _message = 'URL inválida');
      return;
    }
    await _run(() async {
      final result = await _service.importRemote(
        uri: uri,
        playlistId: 'playlist-' + DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim().isEmpty ? 'Mi playlist' : _name.text.trim(),
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Importada: ' + result.playlist.entries.length.toString() + ' canales');
      }
    });
  }

  Future<void> _importText() async {
    await _run(() async {
      final result = _service.importText(
        text: _text.text,
        playlistId: 'playlist-' + DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim().isEmpty ? 'Mi playlist' : _name.text.trim(),
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Importada: ' + result.playlist.entries.length.toString() + ' canales');
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = 'Error: ' + error.toString());
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
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            prefixIcon: Icon(Icons.label_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'URL M3U/M3U8',
            hintText: 'https://servidor/lista.m3u',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _busy ? null : _importUrl,
          icon: const Icon(Icons.cloud_download),
          label: const Text('Importar URL'),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
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
          Text(_message!),
        ],
      ],
    ),
  );
}
