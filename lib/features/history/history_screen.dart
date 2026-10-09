import 'package:flutter/material.dart';
import '../../core/history/history_repository.dart';
import '../../core/domain/entities/watch_history.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _historyRepository = HistoryRepository();
  final _playlists = PersistentPlaylistRepository();
  List<WatchHistoryEntry> _items = const [];
  Map<String, PlaylistEntry> _entries = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      await _playlists.load();
      final history = await _historyRepository.load();
      final entries = <String, PlaylistEntry>{};
      for (final playlist in _playlists.playlists) {
        for (final entry in playlist.entries) {
          entries['${playlist.id}::${entry.channel.id}'] = entry;
          entries.putIfAbsent(entry.channel.id, () => entry);
        }
      }
      if (!mounted) return;
      setState(() { _items = history; _entries = entries; _loading = false; _error = null; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'No se pudo cargar el historial: $error'; });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Borrar historial'), content: const Text('Se eliminará el historial de reproducciones de este dispositivo. Esta acción no elimina tus playlists ni tus favoritos.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Borrar historial'))]));
    if (confirmed != true) return;
    await _historyRepository.clear();
    await _load();
  }

  String _duration(Duration duration) {
    final total = duration.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    if (minutes > 0) return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    return '${seconds}s';
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget body;

    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Aún no hay reproducciones', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Los canales que reproduzcas aparecerán aquí con la fecha y la duración de la sesión.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = _items[index];
          final entry = _entries['${item.playlistId}::${item.channelId}'] ?? _entries[item.channelId];
          final localTime = item.startedAt.toLocal();
          final date = '${localTime.day.toString().padLeft(2, '0')}/${localTime.month.toString().padLeft(2, '0')}/${localTime.year} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: const Icon(Icons.play_arrow_rounded),
              ),
              title: Text(entry?.channel.displayName ?? item.channelId, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('$date · ${_duration(item.duration)}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Borrar historial',
              onPressed: _loading ? null : _clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: body,
    );
  }
}
