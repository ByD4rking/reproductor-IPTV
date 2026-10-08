import 'package:flutter/material.dart';
import '../../core/domain/entities/favorite.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/favorites/favorite_repository.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _favorites = FavoriteRepository();
  final _playlists = PersistentPlaylistRepository();
  List<Favorite> _items = const [];
  Map<String, PlaylistEntry> _entries = const {};
  Map<String, String> _playlistNames = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      await _playlists.load();
      final favorites = await _favorites.load();
      final entries = <String, PlaylistEntry>{};
      final names = <String, String>{};
      for (final playlist in _playlists.playlists) {
        names[playlist.id] = playlist.name;
        for (final entry in playlist.entries) {
          entries['${playlist.id}::${entry.channel.id}'] = entry;
          entries.putIfAbsent(entry.channel.id, () => entry);
        }
      }
      if (!mounted) return;
      setState(() { _items = favorites; _entries = entries; _playlistNames = names; _loading = false; _error = null; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'No se pudieron cargar los favoritos: $error'; });
    }
  }

  Future<void> _remove(Favorite favorite) async {
    await _favorites.remove(favorite.channelId, playlistId: favorite.preferredPlaylistId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos'), actions: [IconButton(tooltip: 'Actualizar', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 42), const SizedBox(height: 12), Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])) )
          : _items.isEmpty ? Center(child: Padding(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_border_rounded, size: 56, color: theme.colorScheme.primary), const SizedBox(height: 16), Text('Tus canales favoritos aparecerán aquí', textAlign: TextAlign.center, style: theme.textTheme.titleLarge), const SizedBox(height: 8), Text('Marca la estrella de un canal para tenerlo a mano en esta sección.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))])) )
          : ListView.separated(padding: const EdgeInsets.all(16), itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
              final favorite = _items[index];
              final entry = _entries['${favorite.preferredPlaylistId}::${favorite.channelId}'] ?? _entries[favorite.channelId];
              final playlistName = favorite.preferredPlaylistId == null ? null : _playlistNames[favorite.preferredPlaylistId];
              return Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), leading: CircleAvatar(backgroundColor: theme.colorScheme.primaryContainer, foregroundColor: theme.colorScheme.onPrimaryContainer, child: const Icon(Icons.live_tv_rounded)), title: Text(entry?.channel.displayName ?? favorite.channelId, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text([if (playlistName != null) playlistName, favorite.preferredSourceId == null ? 'Fuente automática' : 'Fuente preferida configurada'].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: IconButton(tooltip: 'Quitar de favoritos', onPressed: () => _remove(favorite), icon: const Icon(Icons.star_rounded))));
            }),
    );
  }
}
