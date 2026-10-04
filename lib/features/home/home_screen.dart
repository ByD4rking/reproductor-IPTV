import 'package:flutter/material.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = PersistentPlaylistRepository();
  final _settings = SettingsRepository();
  Playlist? _playlist;
  SearchIndex? _searchIndex;
  bool _loading = true;
  String _query = '';
  String _category = 'Todos';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    await _repository.load();
    var playlists = _repository.playlists;
    final settings = await _settings.load();

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

    if (!mounted) return;
    setState(() {
      _playlist = playlist;
      _searchIndex = playlist == null
          ? null
          : (SearchIndex()..replace(playlist.entries.map((e) => e.channel)));
      _loading = false;
    });
  }

  List<String> get _categories {
    final playlist = _playlist!;
    final values = playlist.entries
        .map((e) => e.category)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todos', ...values];
  }

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
        .where((e) => _category == 'Todos' || e.category == _category)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reproductor IPTV')),
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
                              '${playlist.entries.length} canales · ${_categories.length - 1} categorías'),
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
                child: SizedBox(
                  height: 54,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final category = _categories[index];
                      return ChoiceChip(
                        label: Text(category),
                        selected: category == _category,
                        onSelected: (_) => setState(() => _category = category),
                      );
                    },
                  ),
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
                      entry: entries[index], autofocus: index == 0),
                ),
              ),
            ],
          );
        },
      ),
    );
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
  const _ChannelCard({required this.entry, this.autofocus = false});
  final PlaylistEntry entry;
  final bool autofocus;

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  final _favorites = FavoriteRepository();
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
          values.any((f) => f.channelId == widget.entry.channel.id));
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favorite) {
      await _favorites.remove(widget.entry.channel.id);
    } else {
      await _favorites.setFavorite(Favorite(
        channelId: widget.entry.channel.id,
        preferredSourceId:
            widget.entry.sources.isEmpty ? null : widget.entry.sources.first.id,
      ));
    }
    if (mounted) setState(() => _favorite = !_favorite);
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
                  trailing: IconButton(
                    tooltip: _favorite ? 'Quitar favorito' : 'Agregar favorito',
                    onPressed: _toggleFavorite,
                    icon: Icon(_favorite ? Icons.star : Icons.star_outline),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
