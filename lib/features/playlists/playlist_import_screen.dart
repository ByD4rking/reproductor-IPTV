import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/importer/playlist_import_service.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
import '../../core/playlists/repository/playlist_repository.dart';
import '../../core/playlists/repository/remote_playlist_state_repository.dart';
import '../../core/playlists/xtream/xtream_import_service.dart';
import 'local_playlist_transfer_screen.dart';
import '../qr/qr_scan_screen.dart';
import '../../core/transfer/qr_transfer_client.dart';
import '../../core/settings/settings_repository.dart';

class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({required this.repository, this.onPlaylistSelected, super.key});
  final PlaylistRepository repository;
  final Future<void> Function(String playlistId)? onPlaylistSelected;

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final _url = TextEditingController();
  final _name = TextEditingController(text: 'Mi playlist');
  final _text = TextEditingController();
  late final PlaylistImportService _service;
  late final XtreamImportService _xtream;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _service = PlaylistImportService(
      stateRepository: RemotePlaylistStateRepository(),
    );
    _xtream = XtreamImportService();
    _loadSavedPlaylists();
  }

  Future<void> _loadSavedPlaylists() async {
    try {
      await widget.repository.load();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'No se pudieron cargar las playlists guardadas: $error');
      }
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _name.dispose();
    _text.dispose();
    _service.dispose();
    _xtream.dispose();
    super.dispose();
  }

  String get _playlistName =>
      _name.text.trim().isEmpty ? 'Mi playlist' : _name.text.trim();

  String _newId() => 'playlist-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _importUrl() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null) {
      setState(() => _message = 'URL inválida');
      return;
    }
    await _run(() async {
      final existing = widget.repository.playlists.where(
        (playlist) => playlist.sourceUri == uri,
      );
      final previous = existing.isEmpty ? null : existing.first;
      final result = await _service.importRemote(
        uri: uri,
        playlistId: previous?.id ?? _newId(),
        name: _playlistName,
        previous: previous,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message = previous == null
            ? 'Nueva lista guardada: ${result.playlist.entries.length} canales'
            : 'Lista actualizada: ${result.playlist.entries.length} canales');
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
      final result = await _service.importText(
        text: text,
        playlistId: _newId(),
        name: _name.text.trim().isEmpty
            ? name.replaceFirst(RegExp(r'\.[^.]+$'), '')
            : _playlistName,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Archivo guardado: ${result.playlist.entries.length} canales');
      }
    });
  }

  Future<void> _importXtream() async {
    final server = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController(text: 'Xtream IPTV');

    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar cuenta Xtream'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Servidor',
                  hintText: 'https://servidor:puerto',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Usuario'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nombre de la lista'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Las credenciales solo se usan para esta importación y no se guardan en la playlist.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              [
                server.text.trim(),
                username.text.trim(),
                password.text,
                name.text.trim(),
              ],
            ),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    server.dispose();
    username.dispose();
    password.dispose();
    name.dispose();

    if (values == null) return;
    final uri = Uri.tryParse(values[0]);
    if (uri == null) {
      setState(() => _message = 'Servidor Xtream inválido');
      return;
    }

    await _run(() async {
      final playlist = await _xtream.importLiveChannels(
        server: uri,
        username: values[1],
        password: values[2],
        playlistName: values[3],
      );
      await widget.repository.upsert(playlist);
      if (mounted) {
        setState(() => _message =
            'Xtream guardado: ${playlist.entries.length} canales. Las credenciales no quedaron almacenadas.');
      }
    });
  }

  Future<void> _importText() async {
    await _run(() async {
      final result = _service.importText(
        text: _text.text,
        playlistId: _newId(),
        name: _playlistName,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message =
            'Texto guardado: ${result.playlist.entries.length} canales');
      }
    });
  }

  Future<void> _usePlaylist(Playlist playlist) async {
    // The playlist manager owns activation so every caller uses the same
    // behavior and cannot discard the selection result.
    if (widget.onPlaylistSelected != null) {
      await widget.onPlaylistSelected!(playlist.id);
    } else {
      await SettingsRepository().setActivePlaylistId(playlist.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop(playlist.id);
  }

  Future<void> _rename(Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar lista'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == playlist.name) return;

    await widget.repository.upsert(Playlist(
      id: playlist.id,
      name: name,
      entries: playlist.entries,
      sourceUri: playlist.sourceUri,
      rawContentHash: playlist.rawContentHash,
      updatedAt: playlist.updatedAt,
    ));
    if (mounted) setState(() {});
  }

  Future<void> _delete(Playlist playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text(
          'Se eliminará “${playlist.name}” del almacenamiento de la aplicación. '
          'Esta acción no elimina ninguna otra lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await widget.repository.remove(playlist.id);
    final settings = await SettingsRepository().load();
    if (settings.activePlaylistId == playlist.id) {
      await SettingsRepository().setActivePlaylistId(null);
    }
    if (mounted) {
      setState(() => _message = 'Lista eliminada manualmente.');
    }
  }

  Future<void> _refresh(Playlist playlist) async {
    if (playlist.id.startsWith('xtream-')) {
      setState(() => _message =
          'Las cuentas Xtream no guardan las credenciales. Vuelve a importarlas para actualizar.');
      return;
    }

    final uri = playlist.sourceUri;
    if (uri == null) {
      setState(() => _message =
          'Esta lista es local y no tiene una URL remota para actualizar.');
      return;
    }

    await _run(() async {
      final result = await _service.importRemote(
        uri: uri,
        playlistId: playlist.id,
        name: playlist.name,
        previous: playlist,
      );
      await widget.repository.upsert(result.playlist);
      if (mounted) {
        setState(() => _message = result.replaced
            ? 'Lista actualizada correctamente.'
            : 'La URL no cambió; se conserva la copia local.');
      }
    });
  }

  Future<void> _openLocalTransfer() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalPlaylistTransferScreen(
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _loadSavedPlaylists();
  }

  Future<void> _showTvTransferHelp() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PC o teléfono → TV'),
        content: const Text(
          'La lista que está en tu PC o teléfono no aparece automáticamente '
          'en un Smart TV.\\n\\n'
          'Android TV / Google TV / Fire TV permiten seleccionar un archivo '
          'local desde un proveedor de archivos compatible.\\n\\n'
          'En LG webOS y Samsung Tizen todavía necesitamos un canal de '
          'transferencia específico (QR/código o servicio local seguro). '
          'La aplicación no lo presenta como implementado hasta tenerlo '
          'realmente construido y probado.',
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

  Future<void> _scanTvQr() async {
    final payload = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (!mounted || payload == null) return;
    await widget.repository.load();
    final playlists = widget.repository.playlists;
    if (playlists.isEmpty) {
      setState(() => _message = 'Primero agrega una playlist para enviarla a la TV.');
      return;
    }
    final selected = await showDialog<Playlist>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Enviar playlist a la TV'),
        children: playlists.map((playlist) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, playlist),
          child: Text(playlist.name),
        )).toList(),
      ),
    );
    if (selected == null || !mounted) return;
    final lines = <String>['#EXTM3U'];
    for (final entry in selected.entries) {
      for (final source in entry.sources) {
        final attrs = <String>[];
        if (entry.channel.tvgId?.isNotEmpty == true) attrs.add('tvg-id="' + entry.channel.tvgId! + '"');
        if (entry.logoUrl != null) attrs.add('tvg-logo="' + entry.logoUrl.toString() + '"');
        if (entry.category?.isNotEmpty == true) attrs.add('group-title="' + entry.category! + '"');
        if (source.userAgent != null) attrs.add('http-user-agent="' + source.userAgent! + '"');
        lines.add('#EXTINF:-1' + (attrs.isEmpty ? '' : ' ' + attrs.join(' ')) + ',' + entry.channel.displayName);
        lines.add(source.url.toString());
      }
    }
    try {
      await QrTransferClient.sendPlaylist(sessionUrl: payload.url, content: lines.join('\n'));
      if (mounted) setState(() => _message = 'Playlist enviada correctamente a la TV.');
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo enviar la playlist: ' + error.toString());
    }
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
  Widget build(BuildContext context) {
    final playlists = widget.repository.playlists;
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar y administrar playlists')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Agregar playlist',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Puedes guardar varias listas. Cada una queda persistida en los '
            'datos privados de la aplicación y no depende de la caché.',
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
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null : _importUrl,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Agregar / actualizar URL'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importFile,
            icon: const Icon(Icons.file_open),
            label: const Text('Cargar archivo M3U/M3U8/TXT'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importXtream,
            icon: const Icon(Icons.account_tree_outlined),
            label: const Text('Agregar Xtream Codes'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _openLocalTransfer,
            icon: const Icon(Icons.wifi),
            label: const Text('Recibir playlist desde PC/teléfono'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scanTvQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Vincular TV / TV Box por QR'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _showTvTransferHelp,
            icon: const Icon(Icons.devices_other),
            label: const Text('Opciones para Smart TV'),
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
            label: const Text('Guardar contenido'),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (_message != null) ...[
            const SizedBox(height: 18),
            SelectableText(_message!),
          ],
          const SizedBox(height: 28),
          Text(
            'Mis playlists (${playlists.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (playlists.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.playlist_add),
                title: Text('No hay playlists guardadas'),
                subtitle: Text('Agrega una URL, archivo o contenido M3U.'),
              ),
            )
          else
            ...playlists.map(
              (playlist) => Card(
                child: ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(playlist.name),
                  subtitle: Text(
                    '${playlist.entries.length} canales'
                    '${playlist.sourceUri == null ? ' · archivo/contenido local' : ' · URL guardada'}',
                  ),
                  onTap: () => _usePlaylist(playlist),
                  trailing: Wrap(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : () => _usePlaylist(playlist),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Usar'),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          switch (action) {
                            case 'refresh':
                              await _refresh(playlist);
                            case 'rename':
                              await _rename(playlist);
                            case 'delete':
                              await _delete(playlist);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'refresh', child: Text('Actualizar')),
                          PopupMenuItem(
                              value: 'rename', child: Text('Renombrar')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
