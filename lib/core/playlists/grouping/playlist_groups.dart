import '../../domain/entities/playlist.dart';

class PlaylistGroup {
  const PlaylistGroup({
    required this.name,
    required this.entries,
  });

  final String name;
  final List<PlaylistEntry> entries;

  int get count => entries.length;
}

class PlaylistGroups {
  const PlaylistGroups._();

  static List<PlaylistGroup> fromPlaylist(Playlist playlist) {
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

    groups.sort((a, b) {
      if (a.name == 'Sin categoría') return 1;
      if (b.name == 'Sin categoría') return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(groups);
  }
}
