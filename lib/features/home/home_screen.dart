import 'package:flutter/material.dart';
import '../../core/domain/entities/playlist.dart';
import '../../core/playlists/m3u/m3u_parser.dart';
import '../../core/search/search_index.dart';
import '../player/player_screen.dart';
import '../playlists/playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Playlist _playlist;
  late final SearchIndex _searchIndex;
  String _query = '';
  String _category = 'Todos';

  @override
  void initState() {
    super.initState();
    _playlist = const M3uParser().parse(
      _demoM3u(), playlistId: 'demo', name: 'Demo IPTV',
    );
    _searchIndex = SearchIndex()..replace(_playlist.entries.map((e) => e.channel));
  }

  List<String> get _categories {
    final values = _playlist.entries.map((e) => e.category)
        .whereType<String>().where((v) => v.isNotEmpty).toSet().toList()..sort();
    return ['Todos', ...values];
  }

  List<PlaylistEntry> get _visibleEntries {
    final candidates = _query.trim().isEmpty
        ? _playlist.entries
        : _searchIndex.search(_query).map((channel) => _playlist.entries.firstWhere(
              (entry) => entry.channel.id == channel.id,
            ));
    return candidates.where((e) => _category == 'Todos' || e.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reproductor IPTV'),
        actions: [
          IconButton(
            tooltip: 'Playlists',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: _playlist)),
            ),
            icon: const Icon(Icons.playlist_play),
          ),
        ],
      ),
      drawer: NavigationDrawer(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: Text('Reproductor IPTV', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          NavigationDrawerDestination(icon: Icon(Icons.live_tv), label: Text('TV en directo')),
          NavigationDrawerDestination(icon: Icon(Icons.star_outline), label: Text('Favoritos')),
          NavigationDrawerDestination(icon: Icon(Icons.history), label: Text('Historial')),
          NavigationDrawerDestination(icon: Icon(Icons.event_note), label: Text('EPG')),
          NavigationDrawerDestination(icon: Icon(Icons.settings_outlined), label: Text('Ajustes')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1400 ? 5 : constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 700 ? 3 : 2;
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
                          const Text('TV en directo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(_playlist.entries.length.toString() + ' canales · ' + (_categories.length - 1).toString() + ' categorías'),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) => setState(() => _query = value),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: 'Buscar canal, TVG-ID o nombre...',
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
                  itemBuilder: (_, index) => _ChannelCard(entry: entries[index]),
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

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.entry});
  final PlaylistEntry entry;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlayerScreen(entry: entry)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: ColoredBox(
              color: Color(0xFF151B24),
              child: Center(child: Icon(Icons.live_tv, size: 48)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Text(entry.channel.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    ),
  );
}
