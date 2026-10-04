import '../../domain/entities/playlist.dart';
import '../organization/playlist_organization.dart';

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
    PlaylistOrganization organization = const PlaylistOrganization(),
  }) {
    final grouped = <String, List<PlaylistEntry>>{};
    final folderById = {
      for (final folder in organization.folders) folder.id: folder,
    };

    for (final entry in playlist.entries) {
      final assignedId = organization.assignments[PlaylistOrganizationRepository.entryKey(entry)] ??
          organization.assignments[entry.id];
      final assigned = assignedId == null ? null : folderById[assignedId];
      if (assigned != null && !assigned.hidden) {
        grouped.putIfAbsent(assigned.name, () => <PlaylistEntry>[]).add(entry);
        continue;
      }
      if (assigned != null && assigned.hidden) continue;

      final raw = entry.category?.trim();
      final name = raw == null || raw.isEmpty ? 'Sin categoría' : raw;
      final id = 'group:${name.toLowerCase()}';
      final folder = folderById[id];
      if (folder?.hidden == true) continue;
      grouped.putIfAbsent(name, () => <PlaylistEntry>[]).add(entry);
    }

    final groups = <PlaylistGroup>[];
    for (final item in grouped.entries) {
      groups.add(PlaylistGroup(name: item.key, entries: List.unmodifiable(item.value)));
    }

    if (favoriteChannelIds.isNotEmpty) {
      final favorites = playlist.entries
          .where((entry) => favoriteChannelIds.contains(entry.channel.id))
          .toList(growable: false);
      if (favorites.isNotEmpty) {
        groups.insert(0, PlaylistGroup(
          name: 'Favoritos',
          entries: List.unmodifiable(favorites),
          isFavorites: true,
        ));
      }
    }

    groups.sort((a, b) {
      if (a.isFavorites) return -1;
      if (b.isFavorites) return 1;
      final af = organization.folders.where((f) => f.name == a.name);
      final bf = organization.folders.where((f) => f.name == b.name);
      final ao = af.isEmpty ? 999999 : af.first.order;
      final bo = bf.isEmpty ? 999999 : bf.first.order;
      if (ao != bo) return ao.compareTo(bo);
      if (a.name == 'Sin categoría') return 1;
      if (b.name == 'Sin categoría') return -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(groups);
  }
}
