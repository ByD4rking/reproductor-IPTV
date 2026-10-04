import 'package:flutter/material.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
import '../../core/playlists/grouping/playlist_groups.dart';
import '../../core/search/search_index.dart';
import '../player/player_screen.dart';
import '../playlists/playlist_import_screen.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';
import '../favorites/favorites_screen.dart';
import '../history/history_screen.dart';
import '../epg/epg_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/favorites/favorite_repository.dart';
import '../../core/domain/entities/favorite.dart';
import '../../core/platform/tv_focus.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/playlists/organization/playlist_organization.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = PersistentPlaylistRepository();
  final _settings = SettingsRepository();
  final _organizationRepository = PlaylistOrganizationRepository();
  Playlist? _playlist;
  SearchIndex? _searchIndex;
  bool _loading = true;
  String _query = '';
  String _category = 'Todos';
  Set<String> _favoriteChannelIds = <String>{};
  PlaylistOrganization _organization = const PlaylistOrganization();

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    await _repository.load();
    var playlists = _repository.playlists;
    final settings = await _settings.load();
    final favorites = await FavoriteRepository().load();

    if (playlists.isNotEmpty && !settings.demoSeeded) {
      await _settings.markDemoSeeded();
    } else if (playlists.isEmpty && !settings.demoSeeded) {
      final demo = const M3uParser()
          .parse(_demoM3u(), playlistId: 'demo', name: 'Demo IPTV');
      await _repository.upsert(demo);
      await _settings.markDemoSeeded();
      playlists = _repository.playlists;
    }

    final activeId = settings.activePlaylistId;
    final matches = activeId == null
        ? const <Playlist>[]
        : playlists.where((playlist) => playlist.id == activeId).toList();
    final selected = matches.isEmpty ? null : matches.first;
    final playlist = selected ?? (playlists.isEmpty ? null : playlists.first);

    if (playlist != null && activeId != playlist.id) {
      await _settings.setActivePlaylistId(playlist.id);
    }

    final organization = playlist == null
        ? const PlaylistOrganization()
        : await _organizationRepository.syncWithGroups(
            playlist.id,
            playlist.entries.map((entry) => entry.category?.trim().isEmpty ?? true
                ? 'Sin categoría'
                : (entry.category?.trim() ?? 'Sin categoría')),
          );

    if (!mounted) return;
    setState(() {
      _playlist = playlist;
      _organization = organization;
      _favoriteChannelIds = favorites
          .where((favorite) =>
              favorite.preferredPlaylistId == null ||
              favorite.preferredPlaylistId == playlist?.id)
          .map((favorite) => favorite.channelId)
          .toSet();
      _searchIndex = playlist == null
          ? null
          : (SearchIndex()..replace(playlist.entries.map((e) => e.channel)));
      _loading = false;
    });
  }

  List<PlaylistGroup> get _groups => PlaylistGroups.fromPlaylist(
        _playlist!,
        favoriteChannelIds: _favoriteChannelIds,
        organization: _organization,
      );

  List<PlaylistEntry> get _visibleEntries {
    final playlist = _playlist!;
    final index = _searchIndex!;
    final candidates = _query.trim().isEmpty
        ? playlist.entries
        : index.search(_query).expand((channel) {
            for (final entry in playlist.entries) {
              if (entry.channel.id == channel.id) return [entry];
            }
            return const <PlaylistEntry>[];
          });
    return candidates
        .where((e) =>
            _category == 'Todos' ||
            (_category == 'Favoritos'
                ? _favoriteChannelIds.contains(e.channel.id)
                : e.category == _category))
        .toList();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadLibrary();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_playlist == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reproductor IPTV'),
          actions: [
            IconButton(
              tooltip: 'Ajustes',
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: Center(
          child: FilledButton.icon(
            onPressed: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => PlaylistImportScreen(repository: _repository),
                ),
              );
              if (selected != null) {
                await _settings.setActivePlaylistId(selected);
              }
              await _loadLibrary();
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Agregar playlist'),
          ),
        ),
      );
    }
    final playlist = _playlist!;
    final entries = _visibleEntries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor IPTV'),
        actions: [
          IconButton(
            tooltip: 'Playlists',
            onPressed: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => PlaylistImportScreen(repository: _repository),
                ),
              );
              if (selected != null) {
                await _settings.setActivePlaylistId(selected);
              }
              await _loadLibrary();
            },
            icon: const Icon(Icons.playlist_play),
          ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          final pages = <Widget>[
            const HomeScreen(),
            const FavoritesScreen(),
            const HistoryScreen(),
            const EpgScreen(),
            const SettingsScreen(),
          ];
          if (index < pages.length && index > 0) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => pages[index]));
          }
        },
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Text('Reproductor IPTV',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          NavigationDrawerDestination(
              icon: Icon(Icons.live_tv), label: Text('TV en directo')),
          NavigationDrawerDestination(
              icon: Icon(Icons.star_outline), label: Text('Favoritos')),
          NavigationDrawerDestination(
              icon: Icon(Icons.history), label: Text('Historial')),
          NavigationDrawerDestination(
              icon: Icon(Icons.event_note), label: Text('EPG')),
          NavigationDrawerDestination(
              icon: Icon(Icons.settings_outlined), label: Text('Ajustes')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1400
              ? 5
              : constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 700
                      ? 3
                      : 2;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TV en directo',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                              '${playlist.entries.length} canales · ${_groups.length} categorías'),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Buscar canal, TVG-ID o nombre...',
                              filled: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _PlaylistSwitcher(
                  playlists: _repository.playlists,
                  active: playlist,
                  onSelected: (selected) async {
                    await _settings.setActivePlaylistId(selected.id);
                    if (mounted) {
                      setState(() {
                        _playlist = selected;
                        _category = 'Todos';
                        _organization = const PlaylistOrganization();
                        _favoriteChannelIds = <String>{};
                        _query = '';
                        _searchIndex = SearchIndex()
                          ..replace(selected.entries.map((e) => e.channel));
                        FavoriteRepository().load().then((values) {
                          if (!mounted || _playlist?.id != selected.id) return;
                          setState(() {
                            _favoriteChannelIds = values
                                .where((favorite) =>
                                    favorite.preferredPlaylistId == null ||
                                    favorite.preferredPlaylistId == selected.id)
                                .map((favorite) => favorite.channelId)
                                .toSet();
                          });
                        });
                      });
                    }
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_copy_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Carpetas',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        tooltip: 'Crear carpeta',
                        onPressed: _createFolder,
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                      IconButton(
                        tooltip: 'Administrar carpetas',
                        onPressed: _manageFolders,
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 92,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _groups.length + 1,
                  itemBuilder: (_, index) {
                    if (index == 0) {
                      return _FolderCard(
                        name: 'Todos',
                        count: playlist.entries.length,
                        selected: _category == 'Todos',
                        onTap: () => setState(() => _category = 'Todos'),
                      );
                    }
                    final group = _groups[index - 1];
                    return _FolderCard(
                      name: group.name,
                      count: group.count,
                      selected: _category == group.name,
                      onTap: () => setState(() => _category = group.name),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: entries.length,
                  itemBuilder: (_, index) => _ChannelCard(
                      entry: entries[index], playlistId: playlist.id, autofocus: index == 0, onMoveToFolder: _moveEntryToFolder, onFavoriteChanged: (isFavorite) {
                        setState(() {
                          final next = <String>{..._favoriteChannelIds};
                          if (isFavorite) {
                            next.add(entries[index].channel.id);
                          } else {
                            next.remove(entries[index].channel.id);
                          }
                          _favoriteChannelIds = next;
                        });
                      }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear carpeta'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await _organizationRepository.createFolder(_playlist!.id, name);
    _organization = await _organizationRepository.syncWithGroups(
      _playlist!.id,
      _playlist!.entries.map((entry) => entry.category?.trim().isEmpty ?? true ? 'Sin categoría' : (entry.category?.trim() ?? 'Sin categoría')),
    );
    if (mounted) setState(() {});
  }

  Future<void> _moveEntryToFolder(PlaylistEntry entry) async {
    final folders = _organization.folders.where((folder) => !folder.hidden).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final selected = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mover canal a carpeta'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Usar categoría original'),
          ),
          ...folders.where((folder) => folder.custom).map((folder) =>
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, folder.id),
              child: Text(folder.name),
            )),
        ],
      ),
    );
    if (selected == null) return;
    await _organizationRepository.moveEntry(
      _playlist!.id, entry.id, selected.isEmpty ? null : selected,
    );
    _organization = await _organizationRepository.load(_playlist!.id);
    if (mounted) setState(() => _category = 'Todos');
  }

  Future<void> _manageFolders() async {
    final folders = [..._organization.folders]..sort((a, b) => a.order.compareTo(b.order));
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Administrar carpetas'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: folders.map((folder) => ListTile(
              leading: Icon(folder.custom ? Icons.folder : Icons.folder_copy_outlined),
              title: Text(folder.name),
              subtitle: Text(folder.custom ? 'Carpeta personalizada' : 'Categoría original M3U'),
              trailing: Wrap(
                spacing: 0,
                children: [
                  IconButton(
                    tooltip: 'Subir',
                    onPressed: folder.order == 0 ? null : () async {
                      await _organizationRepository.reorder(_playlist!.id, folder.id, -1);
                      if (context.mounted) Navigator.pop(context);
                      await _reloadOrganization();
                    },
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Bajar',
                    onPressed: () async {
                      await _organizationRepository.reorder(_playlist!.id, folder.id, 1);
                      if (context.mounted) Navigator.pop(context);
                      await _reloadOrganization();
                    },
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  if (folder.custom)
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'rename') await _renameFolder(folder);
                        if (action == 'delete') await _deleteFolder(folder);
                        if (context.mounted) Navigator.pop(context);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                ],
              ),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }

  Future<void> _renameFolder(PlaylistFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar carpeta'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await _organizationRepository.renameFolder(_playlist!.id, folder.id, name);
      await _reloadOrganization();
    }
  }

  Future<void> _deleteFolder(PlaylistFolder folder) async {
    await _organizationRepository.deleteFolder(_playlist!.id, folder.id);
    await _reloadOrganization();
  }

  Future<void> _reloadOrganization() async {
    _organization = await _organizationRepository.load(_playlist!.id);
    if (mounted) setState(() {});
  }

  static String _demoM3u() => '#EXTM3U\n'
      '#EXTINF:-1 tvg-id="demo-news" group-title="Noticias",Demo News\n'
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8\n'
      '#EXTINF:-1 tvg-id="demo-sports" group-title="Deportes",Demo Sports\n'
      'https://test-streams.mux.dev/test_001/stream.m3u8\n'
      '#EXTINF:-1 tvg-id="demo-movie" group-title="Películas",Demo Cinema\n'
      'https://storage.googleapis.com/coverr-main/mp4/Mt_Baker.mp4\n';
}

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({required this.entry, required this.playlistId, required this.onFavoriteChanged, required this.onMoveToFolder, this.autofocus = false});
  final PlaylistEntry entry;
  final String playlistId;
  final ValueChanged<bool> onFavoriteChanged;
  final ValueChanged<PlaylistEntry> onMoveToFolder;
  final bool autofocus;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  final _favorites = FavoriteRepository();
  String get _playlistId => widget.playlistId;
  bool _favorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
  }

  Future<void> _loadFavorite() async {
    final values = await _favorites.load();
    if (mounted) {
      setState(() => _favorite =
          values.any((f) =>
          f.channelId == widget.entry.channel.id &&
          (f.preferredPlaylistId == null || f.preferredPlaylistId == _playlistId)));
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favorite) {
      await _favorites.remove(widget.entry.channel.id, playlistId: _playlistId);
    } else {
      await _favorites.setFavorite(Favorite(
        channelId: widget.entry.channel.id,
        preferredPlaylistId: _playlistId,
        preferredSourceId:
            widget.entry.sources.isEmpty ? null : widget.entry.sources.first.id,
      ));
    }
    if (mounted) {
      final next = !_favorite;
      setState(() => _favorite = next);
      widget.onFavoriteChanged(next);
    }
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(entry: widget.entry)),
    );
  }

  @override
  Widget build(BuildContext context) => TvFocusable(
        autofocus: widget.autofocus,
        onActivate: _openPlayer,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openPlayer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: ColoredBox(
                    color: Color(0xFF151B24),
                    child: Center(child: Icon(Icons.live_tv, size: 48)),
                  ),
                ),
                ListTile(
                  dense: true,
                  title: Text(widget.entry.channel.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Mover a carpeta',
                        onPressed: () => widget.onMoveToFolder(widget.entry),
                        icon: const Icon(Icons.drive_file_move_outlined),
                      ),
                      IconButton(
                    tooltip: _favorite ? 'Quitar favorito' : 'Agregar favorito',
                    onPressed: _toggleFavorite,
                    icon: Icon(_favorite ? Icons.star : Icons.star_outline),
                  ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}


class _PlaylistSwitcher extends StatelessWidget {
  const _PlaylistSwitcher({
    required this.playlists,
    required this.active,
    required this.onSelected,
  });

  final List<Playlist> playlists;
  final Playlist active;
  final Future<void> Function(Playlist) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.playlist_play),
          title: Text(active.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(active.entries.length.toString() + ' canales · lista activa'),
          trailing: PopupMenuButton<String>(
            tooltip: 'Cambiar playlist',
            onSelected: (id) {
              final selected = playlists.where((p) => p.id == id);
              if (selected.isNotEmpty) onSelected(selected.first);
            },
            itemBuilder: (_) => playlists
                .map((playlist) => PopupMenuItem<String>(
                      value: playlist.id,
                      child: Row(
                        children: [
                          Icon(playlist.id == active.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(playlist.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onActivate: onTap,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(selected ? Icons.folder : Icons.folder_outlined, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(count.toString() + ' canales'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
