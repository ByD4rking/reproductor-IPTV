import '../../domain/entities/playlist.dart';

class PlaylistGroup {
  const PlaylistGroup({
    required this.name,
    required this.entries,
    this.isFavorites = false,
  });

  final String name;
  final List<PlaylistEntry> entries;
  final bool isFavorites;

  int get count => entries.length;
}

class PlaylistGroups {
  const PlaylistGroups._();

  static List<PlaylistGroup> fromPlaylist(
    Playlist playlist, {
    Set<String> favoriteChannelIds = const <String>{},
  }) {
    final grouped = <String, List<PlaylistEntry>>{};

    for (final entry in playlist.entries) {
      final raw = entry.category?.trim();
      final name = raw == null || raw.isEmpty ? 'Sin categoría' : raw;
      grouped.putIfAbsent(name, () => <PlaylistEntry>[]).add(entry);
    }

    final groups = grouped.entries
        .map((item) => PlaylistGroup(
              name: item.key,
              entries: List.unmodifiable(item.value),
            ))
        .toList();

    if (favoriteChannelIds.isNotEmpty) {
      final favorites = playlist.entries
          .where((entry) => favoriteChannelIds.contains(entry.channel.id))
          .toList(growable: false);
      if (favorites.isNotEmpty) {
        groups.insert(
          0,
          PlaylistGroup(
            name: 'Favoritos',
            entries: List.unmodifiable(favorites),
            isFavorites: true,
          ),
        );
      }
    }

    groups.sort((a, b) {
      if (a.isFavorites) return -1;
      if (b.isFavorites) return 1;
      if (a.name == 'Sin categoría') return 1;
      if (b.name == 'Sin categoría') return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(groups);
  }
}
