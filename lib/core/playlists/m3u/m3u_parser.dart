import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';

class M3uParseException implements Exception {
  const M3uParseException(this.message);
  final String message;
}

class M3uParser {
  const M3uParser({this.maxChannels = 100000, this.maxContentCharacters = 64 * 1024 * 1024, this.maxLineLength = 1024 * 1024});

  final int maxChannels;
  final int maxContentCharacters;
  final int maxLineLength;

  Playlist parse(String content, {String playlistId = 'imported', String name = 'Imported playlist'}) {
    if (content.length > maxContentCharacters) throw const M3uParseException('Playlist content limit exceeded');

    final lines = content.split(RegExp(r'\r?\n'));
    final entries = <PlaylistEntry>[];
    String? pendingExtInf;
    var sourceIndex = 0;

    for (final line in lines) {
      if (line.length > maxLineLength) throw const M3uParseException('Playlist line limit exceeded');
      final value = line.trim();
      if (value.isEmpty) continue;
      if (value.startsWith('#EXTINF:')) {
        pendingExtInf = value;
        continue;
      }
      if (value.startsWith('#') || pendingExtInf == null) continue;

      final uri = Uri.tryParse(value);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
        pendingExtInf = null;
        continue;
      }

      final attrs = _attributes(pendingExtInf);
      final displayName = _displayName(pendingExtInf);
      if (displayName.isEmpty) {
        pendingExtInf = null;
        continue;
      }
      if (entries.length >= maxChannels) throw const M3uParseException('Playlist channel limit exceeded');

      final tvgId = attrs['tvg-id'];
      final channelId = tvgId?.trim().isNotEmpty == true ? tvgId!.trim() : Channel.normalizeIdentity(displayName) + ':' + entries.length.toString();

      final channel = Channel(
        id: channelId,
        displayName: displayName,
        tvgId: tvgId,
        country: attrs['tvg-country'],
        language: attrs['tvg-language'],
      );

      entries.add(PlaylistEntry(
        id: playlistId + ':' + entries.length.toString(),
        channel: channel,
        sources: [
          StreamSource(
            id: playlistId + ':source:' + sourceIndex.toString(),
            url: uri,
            userAgent: attrs['http-user-agent'],
          ),
        ],
        category: attrs['group-title'],
        logoUrl: attrs['tvg-logo'],
      ));
      sourceIndex++;
      pendingExtInf = null;
    }

    if (entries.isEmpty) throw const M3uParseException('Playlist contains no valid channels');

    return Playlist(
      id: playlistId,
      name: name,
      entries: List.unmodifiable(entries),
      rawContentHash: content.hashCode.toString(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, String> _attributes(String line) {
    final out = <String, String>{};
    final regex = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');
    for (final match in regex.allMatches(line)) out[match.group(1)!] = match.group(2)!;
    return out;
  }

  String _displayName(String line) {
    final index = line.indexOf(',');
    return index < 0 ? '' : line.substring(index + 1).trim();
  }
}
