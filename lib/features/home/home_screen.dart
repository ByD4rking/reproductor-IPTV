import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/grouping/playlist_groups.dart';
import '../../core/search/search_index.dart';
import '../player/player_screen.dart';
import '../playlists/playlist_import_screen.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';
import '../favorites/favorites_screen.dart';
import '../history/history_screen.dart';
import '../epg/epg_screen.dart';
import '../video/video_library_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/favorites/favorite_repository.dart';
import '../../core/domain/entities/favorite.dart';
import '../../core/platform/tv_focus.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/playlists/organization/playlist_organization.dart';
import '../../core/playlists/importer/playlist_import_service.dart';
import '../../core/playlists/repository/remote_playlist_state_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = PersistentPlaylistRepository();
  final _settings = SettingsRepository();
  final _organizationRepository = PlaylistOrganizationRepository();
  late final PlaylistImportService _playlistImporter;
  Playlist? _playlist;
  SearchIndex? _searchIndex;
  bool _loading = true;
  String? _loadError;
  String _query = '';
  Timer? _searchDebounce;
  String _category = 'Todos';
  bool _showingChannels = false;
  Set<String> _favoriteChannelIds = <String>{};
  final Map<String, PlaylistEntry> _entryByChannelId = <String, PlaylistEntry>{};
  PlaylistOrganization _organization = const PlaylistOrganization();

  @override
  void initState() {
    super.initState();
    _playlistImporter = PlaylistImportService(
      stateRepository: RemotePlaylistStateRepository(),
    );
    _loadLibrary();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _playlistImporter.dispose();
    super.dispose();
  }

  Future<void> _refreshRemotePlaylist(Playlist playlist) async {
    final uri = playlist.sourceUri;
    if (uri == null) return;

    try {
      final result = await _playlistImporter.importRemote(
        uri: uri,
        playlistId: playlist.id,
        name: playlist.name,
        previous: playlist,
      );
      if (result.replaced) {
        await _repository.upsert(result.playlist);
      }
    } catch (_) {
      // Keep the last known-good local copy when the remote source is
      // temporarily unavailable. Playback must not depend on a refresh.
    }
  }

  Future<void> _loadLibrary() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      await _loadLibraryImpl();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudo abrir la biblioteca local. Reintenta. ($error)';
      });
    }
  }

  Future<void> _loadLibraryImpl() async {
    await _repository.load();
    var playlists = _repository.playlists;
    final settings = await _settings.load();
    final favorites = await FavoriteRepository().load();

    if (playlists.isNotEmpty && !settings.demoSeeded) {
      await _settings.markDemoSeeded();
    }

    final activeId = settings.activePlaylistId;
    final matches = activeId == null
        ? const <Playlist>[]
        : playlists.where((playlist) => playlist.id == activeId).toList();
    final selected = matches.isEmpty ? null : matches.first;
    var playlist = selected ?? (playlists.isEmpty ? null : playlists.first);

    if (playlist != null && activeId != playlist.id) {
      await _settings.setActivePlaylistId(playlist.id);
    }

    // Never block the first paint on a remote playlist refresh. The persisted
    // last-known-good snapshot is immediately usable; refresh continues in the
    // background and atomically replaces it only when a valid new playlist arrives.
    final startupPlaylist = playlist;
    final organization = playlist == null
        ? const PlaylistOrganization()
        : await _organizationRepository.syncWithGroups(
            playlist.id,
            playlist.entries.map((entry) => entry.category?.trim().isEmpty ?? true
                ? 'Sin categoría'
                : (entry.category?.trim() ?? 'Sin categoría')),
          );

    _rebuildEntryIndex(startupPlaylist);
    if (!mounted) return;
    setState(() {
      _playlist = startupPlaylist;
      _organization = organization;
      _favoriteChannelIds = favorites
          .where((favorite) =>
              favorite.preferredPlaylistId == playlist?.id)
          .map((favorite) => favorite.channelId)
          .toSet();
      _searchIndex = playlist == null
          ? null
          : (SearchIndex()..replace(playlist.entries.map((e) => e.channel)));
      _loading = false;
    });

    final remote = startupPlaylist;
    if (remote != null && remote.sourceUri != null) {
      // Fire-and-forget: local playback and navigation stay responsive.
      unawaited(_refreshRemotePlaylist(remote).then((_) async {
        await _repository.load();
        final refreshed = _repository.getById(remote.id);
        if (!mounted || refreshed == null || refreshed.rawContentHash == remote.rawContentHash) {
          return;
        }
        final refreshedOrganization = await _organizationRepository.syncWithGroups(
          refreshed.id,
          refreshed.entries.map((entry) => entry.category?.trim().isEmpty ?? true
              ? 'Sin categoría'
              : (entry.category?.trim() ?? 'Sin categoría')),
        );
        if (!mounted || _playlist?.id != refreshed.id) return;
        _rebuildEntryIndex(refreshed);
        setState(() {
          _playlist = refreshed;
          _organization = refreshedOrganization;
          _searchIndex = SearchIndex()
            ..replace(refreshed.entries.map((entry) => entry.channel));
        });
      }));
    }
  }

  void _rebuildEntryIndex(Playlist? playlist) {
    _entryByChannelId
      ..clear()
      ..addEntries(
        (playlist?.entries ?? const <PlaylistEntry>[])
            .map((entry) => MapEntry(entry.channel.id, entry)),
      );
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
        : index.search(_query)
            .map((channel) => _entryByChannelId[channel.id])
            .whereType<PlaylistEntry>();
    return candidates
        .where((e) {
          if (_category == 'Todos') return true;
          if (_category == 'Favoritos') {
            return _favoriteChannelIds.contains(e.channel.id);
          }
          final assignedId = _organization.assignments[
              PlaylistOrganizationRepository.entryKey(e)];
          final assigned = assignedId == null
              ? null
              : _organization.folders.where((f) => f.id == assignedId);
          if (assigned != null && assigned.isNotEmpty) {
            return assigned.first.name == _category;
          }
          final category = e.category?.trim();
          return (category == null || category.isEmpty)
              ? _category == 'Sin categoría'
              : category == _category;
        })
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
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor IPTV')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_outlined, size: 52,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text('No se pudo abrir la biblioteca',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(_loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _loadLibrary,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Icon(
                          Icons.live_tv_rounded,
                          size: 44,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Tu TV, en un solo lugar',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Agrega una playlist M3U/M3U8 desde una URL o archivo para empezar. '
                        'Tus listas quedarán guardadas en este dispositivo.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
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
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: const Text('Agregar primera playlist'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Configurar aplicación'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
            tooltip: 'Ajustes',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 700
          ? NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) {
                final pages = <Widget>[
                  const HomeScreen(),
                  const FavoritesScreen(),
                  const EpgScreen(),
                  const SettingsScreen(),
                ];
                if (index > 0) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => pages[index]),
                  );
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.live_tv_outlined),
                  selectedIcon: Icon(Icons.live_tv_rounded),
                  label: 'TV',
                ),
                NavigationDestination(
                  icon: Icon(Icons.star_outline_rounded),
                  selectedIcon: Icon(Icons.star_rounded),
                  label: 'Favoritos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note_rounded),
                  label: 'Guía',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Ajustes',
                ),
              ],
            )
          : null,
      drawer: NavigationDrawer(
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          final pages = <Widget>[
            const HomeScreen(),
            const FavoritesScreen(),
            const HistoryScreen(),
            const EpgScreen(),
            const SettingsScreen(),
            const VideoLibraryScreen(),
          ];
          if (index < pages.length && index > 0) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => pages[index]),
            );
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
          NavigationDrawerDestination(
              icon: Icon(Icons.video_library_outlined), label: Text('Vídeos')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          void selectFolder(String name) {
            setState(() {
              _category = name;
              _query = '';
              _showingChannels = true;
            });
          }

          Widget categoryHeading() => Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 18, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_showingChannels)
                      IconButton.filledTonal(
                        tooltip: 'Volver a carpetas',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() {
                          _showingChannels = false;
                          _category = 'Todos';
                          _query = '';
                        }),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    if (_showingChannels) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _query.isNotEmpty ? 'Resultados de búsqueda' : _category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              );

          Widget searchField() => TextField(
                key: ValueKey('search-${playlist.id}'),
                onChanged: (value) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 120),
                    () {
                      if (!mounted) return;
                      setState(() {
                        _query = value.trim();
                        if (_query.isNotEmpty) _showingChannels = true;
                      });
                    },
                  );
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Buscar canal...',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              );

          Widget folderRow(String name, int count, {bool management = false}) =>
              ListTile(
                key: ValueKey('folder-${playlist.id}-$name'),
                selected: _category == name && _showingChannels,
                leading: Icon(name == 'Todos'
                    ? Icons.grid_view_rounded
                    : name == 'Favoritos'
                        ? Icons.star_rounded
                        : Icons.folder_rounded),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: management
                    ? null
                    : Text('$count', style: Theme.of(context).textTheme.labelMedium),
                onTap: () => selectFolder(name),
              );

          Widget folderSidebar() => Container(
                width: wide ? 270 : double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: wide
                      ? Border(
                          right: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        )
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 12, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_copy_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'CARPETAS',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Crear carpeta',
                            onPressed: _createFolder,
                            icon: const Icon(Icons.create_new_folder_outlined),
                          ),
                          IconButton(
                            tooltip: 'Administrar carpetas',
                            onPressed: _manageFolders,
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          folderRow('Todos', playlist.entries.length),
                          ..._groups.map((group) =>
                              folderRow(group.name, group.count)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${playlist.entries.length} canales en esta lista',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              );

          Widget channelGrid() {
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _query.isNotEmpty
                            ? Icons.search_off_rounded
                            : Icons.tv_off_rounded,
                        size: 46,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.isNotEmpty
                            ? 'No encontramos canales'
                            : 'Esta carpeta está vacía',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _query.isNotEmpty
                            ? 'Prueba con otro nombre.'
                            : 'Selecciona otra carpeta para ver sus canales.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _query = '';
                          _category = 'Todos';
                          _showingChannels = wide;
                        }),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Volver a carpetas'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return GridView.builder(
              key: ValueKey('channels-${playlist.id}-$_category'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 1400
                    ? 5
                    : constraints.maxWidth >= 1000
                        ? 4
                        : constraints.maxWidth >= 650
                            ? 3
                            : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemCount: entries.length,
              itemBuilder: (_, index) => _ChannelCard(
                key: ValueKey('${playlist.id}:${entries[index].id}'),
                entry: entries[index],
                playlistId: playlist.id,
                favorite: _favoriteChannelIds.contains(entries[index].channel.id),
                autofocus: index == 0,
                onMoveToFolder: _moveEntryToFolder,
                onFavoriteChanged: (isFavorite) {
                  setState(() {
                    final next = <String>{..._favoriteChannelIds};
                    if (isFavorite) {
                      next.add(entries[index].channel.id);
                    } else {
                      next.remove(entries[index].channel.id);
                    }
                    _favoriteChannelIds = next;
                  });
                },
              ),
            );
          }

          final header = Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TV en directo',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${playlist.name} · ${playlist.entries.length} canales',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(minHeight: 104),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.live_tv_rounded,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TU TELEVISIÓN, EN UN SOLO LUGAR',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${playlist.entries.length} canales disponibles',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                searchField(),
              ],
            ),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 270, child: folderSidebar()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      categoryHeading(),
                      Expanded(child: channelGrid()),
                    ],
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(
                child: _showingChannels
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          categoryHeading(),
                          Expanded(child: channelGrid()),
                        ],
                      )
                    : folderSidebar(),
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
      _playlist!.id,
      PlaylistOrganizationRepository.entryKey(entry),
      selected.isEmpty ? null : selected,
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
                        if (action == 'rename') {
                          await _renameFolder(folder);
                        }
                        if (action == 'delete') {
                          await _deleteFolder(folder);
                        }
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

}

class _ChannelCard extends StatefulWidget {
  const _ChannelCard({
    super.key,
    required this.entry,
    required this.playlistId,
    required this.favorite,
    required this.onFavoriteChanged,
    required this.onMoveToFolder,
    this.autofocus = false,
  });
  final PlaylistEntry entry;
  final String playlistId;
  final bool favorite;
  final ValueChanged<bool> onFavoriteChanged;
  final ValueChanged<PlaylistEntry> onMoveToFolder;
  final bool autofocus;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  final _favorites = FavoriteRepository();
  String get _playlistId => widget.playlistId;
  bool get _favorite => widget.favorite;

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
      widget.onFavoriteChanged(next);
    }
  }

  void _openPlayer() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(entry: widget.entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo = widget.entry.logoUrl;
    return TvFocusable(
      autofocus: widget.autofocus,
      onActivate: _openPlayer,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openPlayer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFF151B24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (logo != null)
                        Image.network(
                          key: ValueKey('${widget.playlistId}:${widget.entry.id}:${logo.toString()}'),
                          logo.toString(),
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.live_tv, size: 46),
                          ),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        )
                      else
                        const Center(child: Icon(Icons.live_tv, size: 46)),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            child: Text(
                              'EN VIVO',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.entry.channel.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: _favorite ? 'Quitar favorito' : 'Agregar favorito',
                      visualDensity: VisualDensity.compact,
                      onPressed: _toggleFavorite,
                      icon: Icon(_favorite ? Icons.star : Icons.star_outline),
                    ),
                    IconButton(
                      tooltip: 'Mover a carpeta',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onMoveToFolder(widget.entry),
                      icon: const Icon(Icons.drive_file_move_outlined),
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
}

