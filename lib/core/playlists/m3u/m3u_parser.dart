import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';
import '../../network/url_policy.dart';

class M3uParseException implements Exception {
  const M3uParseException(this.message);
  final String message;
}

class M3uParser {
  const M3uParser({
    this.maxChannels = 100000,
    this.maxContentCharacters = 64 * 1024 * 1024,
    this.maxLineLength = 1024 * 1024,
    this.urlPolicy = const UrlPolicy(),
  });

  final int maxChannels;
  final int maxContentCharacters;
  final int maxLineLength;
  final UrlPolicy urlPolicy;

  Playlist parse(
    String content, {
    String playlistId = 'imported',
    String name = 'Imported playlist',
  }) {
    if (content.length > maxContentCharacters) {
      throw const M3uParseException('Playlist content limit exceeded');
    }
    return _parseIterable(
      content.split(RegExp(r'\r?\n')),
      playlistId: playlistId,
      name: name,
      rawContentHash: sha256.convert(utf8.encode(content)).toString(),
    );
  }

  Playlist _parseIterable(
    Iterable<String> lines, {
    String playlistId = 'imported',
    String name = 'Imported playlist',
    required String rawContentHash,
  }) {
    final entries = <PlaylistEntry>[];
    final byTvgId = <String, int>{};
    String? pendingExtInf;
    var sourceIndex = 0;

    for (final line in lines) {
      if (line.length > maxLineLength) {
        throw const M3uParseException('Playlist line limit exceeded');
      }
      final value = line.trim();
      if (value.isEmpty) continue;

      if (value.startsWith('#EXTINF:')) {
        pendingExtInf = value;
        continue;
      }
      if (value.startsWith('#') || pendingExtInf == null) continue;

      final uri = Uri.tryParse(value);
      if (uri == null || !urlPolicy.accepts(uri)) {
        pendingExtInf = null;
        continue;
      }

      final attrs = _attributes(pendingExtInf);
      final displayName = _displayName(pendingExtInf);
      if (displayName.isEmpty) {
        pendingExtInf = null;
        continue;
      }

      final tvgId = attrs['tvg-id']?.trim();
      final channelId = tvgId != null && tvgId.isNotEmpty
          ? tvgId
          : '${Channel.normalizeIdentity(displayName)}:${entries.length}';

      final logoText = attrs['tvg-logo']?.trim();
      final logoUrl =
          logoText == null || logoText.isEmpty ? null : Uri.tryParse(logoText);

      final headers = <String, String>{};
      final userAgent = attrs['http-user-agent']?.trim();
      if (userAgent != null && userAgent.isNotEmpty) {
        headers['User-Agent'] = userAgent;
      }
      final referrer = attrs['http-referrer']?.trim();
      if (referrer != null && referrer.isNotEmpty) {
        headers['Referer'] = referrer;
      }
      final origin = attrs['http-origin']?.trim();
      if (origin != null && origin.isNotEmpty) {
        headers['Origin'] = origin;
      }

      final source = StreamSource(
        id: '$playlistId:source:$sourceIndex',
        url: uri,
        userAgent: userAgent,
        headers: Map.unmodifiable(headers),
      );

      if (tvgId != null && tvgId.isNotEmpty) {
        final existingIndex = byTvgId[tvgId];
        if (existingIndex != null) {
          final existing = entries[existingIndex];
          entries[existingIndex] = PlaylistEntry(
            id: existing.id,
            channel: existing.channel,
            sources: List.unmodifiable([...existing.sources, source]),
            category: existing.category ?? attrs['group-title'],
            logoUrl: existing.logoUrl ?? logoUrl,
          );
          sourceIndex++;
          pendingExtInf = null;
          continue;
        }
      }

      if (entries.length >= maxChannels) {
        throw const M3uParseException('Playlist channel limit exceeded');
      }

      final entry = PlaylistEntry(
        id: '$playlistId:${entries.length}',
        channel: Channel(
          id: channelId,
          displayName: displayName,
          tvgId: tvgId,
          country: attrs['tvg-country'],
          language: attrs['tvg-language'],
        ),
        sources: [source],
        category: attrs['group-title'],
        logoUrl: logoUrl,
      );
      entries.add(entry);
      if (tvgId != null && tvgId.isNotEmpty) {
        byTvgId[tvgId] = entries.length - 1;
      }
      sourceIndex++;
      pendingExtInf = null;
    }

    if (entries.isEmpty) {
      throw const M3uParseException('Playlist contains no valid channels');
    }

    return Playlist(
      id: playlistId,
      name: name,
      entries: List.unmodifiable(entries),
      rawContentHash: rawContentHash,
      updatedAt: DateTime.now(),
    );
  }

  Playlist parseLines(
    Iterable<String> lines, {
    String playlistId = 'imported',
    String name = 'Imported playlist',
  }) {
    final digestSink = _DigestSink();
    final hashSink = sha256.startChunkedConversion(digestSink);
    var characters = 0;
    var firstLine = true;

    Iterable<String> normalizedLines() sync* {
      for (final line in lines) {
        if (line.length > maxLineLength) {
          throw const M3uParseException('Playlist line limit exceeded');
        }
        characters += line.length + 1;
        if (characters > maxContentCharacters) {
          throw const M3uParseException('Playlist content limit exceeded');
        }
        if (!firstLine) hashSink.add(const [10]);
        hashSink.add(utf8.encode(line));
        firstLine = false;
        yield line;
      }
    }

    final playlist = _parseIterable(
      normalizedLines(),
      playlistId: playlistId,
      name: name,
      rawContentHash: '',
    );
    hashSink.close();
    final digest = digestSink.value;
    if (digest == null) {
      throw const M3uParseException(
        'No se pudo calcular el hash de la playlist',
      );
    }
    return Playlist(
      id: playlist.id,
      name: playlist.name,
      entries: playlist.entries,
      sourceUri: playlist.sourceUri,
      rawContentHash: digest.toString(),
      updatedAt: playlist.updatedAt,
    );
  }

  Map<String, String> _attributes(String line) {
    final out = <String, String>{};
    final regex = RegExp(
      r'''([A-Za-z0-9_-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s,]+))''',
    );
    for (final match in regex.allMatches(line)) {
      out[match.group(1)!] =
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    }
    return out;
  }

  String _displayName(String line) {
    final index = line.indexOf(',');
    return index < 0 ? '' : line.substring(index + 1).trim();
  }
  class _DigestSink implements Sink<Digest> {
    Digest? value;

    @override
    void add(Digest data) {
      value = data;
    }

    @override
    void close() {}
  }

}
