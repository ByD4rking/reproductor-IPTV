import 'package:flutter/material.dart';

import '../../core/domain/entities/channel.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/domain/entities/stream_source.dart';
import '../../core/video/video_library_repository.dart';
import '../player/player_screen.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  final _repo = VideoLibraryRepository();
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _category = TextEditingController(text: 'Vídeos');
  List<VideoLibraryItem> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _message;
  String _query = '';
  String _categoryFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _message = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'No se pudo cargar la biblioteca: $error';
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    final rawUrl = _url.text.trim();
    final uri = Uri.tryParse(rawUrl);
    if (title.isEmpty || uri == null || !{'http', 'https'}.contains(uri.scheme) || uri.host.isEmpty) {
      setState(() => _message = 'Ingresa un título y una URL HTTP/HTTPS válida.');
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await _repo.upsert(
        VideoLibraryItem(
          id: 'video-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          url: uri,
          category: _category.text.trim().isEmpty ? 'Vídeos' : _category.text.trim(),
        ),
      );
      _title.clear();
      _url.clear();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo guardar el vídeo: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(VideoLibraryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar de la biblioteca'),
        content: Text('Se quitará "${item.title}" de esta biblioteca. No se elimina el archivo del servidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.remove(item.id);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _message = 'No se pudo eliminar el elemento: $error');
    }
  }

  PlaylistEntry _entry(VideoLibraryItem item) => PlaylistEntry(
        id: item.id,
        channel: Channel(id: item.id, displayName: item.title),
        sources: [StreamSource(id: '${item.id}:source', url: item.url)],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = <String>{'Todos', ..._items.map((item) => item.category)}.toList();
    final query = _query.trim().toLowerCase();
    final visible = _items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return matchesQuery && (_categoryFilter == 'Todos' || item.category == _categoryFilter);
    }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de vídeos'),
        actions: [
          IconButton(tooltip: 'Actualizar', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Añadir a tu biblioteca', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Guarda enlaces HTTP/HTTPS a vídeos alojados en NAS, WebDAV, R2/CDN u otros servidores compatibles. Esto no explora carpetas SMB automáticamente.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        TextField(controller: _title, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.movie_outlined))),
                        const SizedBox(height: 10),
                        TextField(controller: _url, keyboardType: TextInputType.url, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'URL del vídeo', hintText: 'https://servidor/ruta/video.mp4', prefixIcon: Icon(Icons.link))),
                        const SizedBox(height: 10),
                        TextField(controller: _category, textInputAction: TextInputAction.done, decoration: const InputDecoration(labelText: 'Categoría', prefixIcon: Icon(Icons.folder_outlined))),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _add,
                            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_rounded),
                            label: Text(_saving ? 'Guardando…' : 'Guardar vídeo'),
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(_message!, style: TextStyle(color: theme.colorScheme.error)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Tu biblioteca · ${_items.length}', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (_items.isNotEmpty) ...[
                  TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar título o categoría', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _categoryFilter == category,
                          onSelected: (_) => setState(() => _categoryFilter = category),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.video_library_outlined, size: 48),
                          SizedBox(height: 12),
                          Text('Tu biblioteca está vacía'),
                          SizedBox(height: 6),
                          Text('Agrega un enlace para guardar una película, serie o vídeo.', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  )
                else if (visible.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.search_off_rounded, size: 40),
                          const SizedBox(height: 10),
                          const Text('No hay vídeos que coincidan con el filtro'),
                          TextButton(
                            onPressed: () => setState(() { _query = ''; _categoryFilter = 'Todos'; }),
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...visible.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor: theme.colorScheme.onSecondaryContainer,
                          child: const Icon(Icons.movie_outlined),
                        ),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.category, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(entry: _entry(item)))),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones de vídeo',
                          onSelected: (action) {
                            if (action == 'play') {
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayerScreen(entry: _entry(item))));
                            } else if (action == 'delete') {
                              _remove(item);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'play', child: Text('Reproducir')),
                            PopupMenuItem(value: 'delete', child: Text('Eliminar de biblioteca')),
                          ],
                        ),
                      ),
                    ),
                  )),
              ],
            ),
    );
  }
}
