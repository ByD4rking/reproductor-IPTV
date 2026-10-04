import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/playlist.dart';
import '../../network/url_policy.dart';
import '../m3u/m3u_parser.dart';
import '../repository/remote_playlist_state_repository.dart';
import '../validator/playlist_validator.dart';

class PlaylistImportResult {
  const PlaylistImportResult({required this.playlist, required this.replaced});
  final Playlist playlist;
  final bool replaced;
}

class PlaylistImportService {
  PlaylistImportService({
    this.parser = const M3uParser(),
    this.validator = const PlaylistValidator(),
    this.urlPolicy = const UrlPolicy(),
    RemotePlaylistStateRepository? stateRepository,
    http.Client? client,
  })  : _stateRepository = stateRepository,
        _client = client ?? http.Client();

  final M3uParser parser;
  final PlaylistValidator validator;
  final UrlPolicy urlPolicy;
  final RemotePlaylistStateRepository? _stateRepository;
  final http.Client _client;

  PlaylistImportResult importText({
    required String text,
    required String playlistId,
    required String name,
    Playlist? previous,
  }) {
    final parsed = parser.parse(text, playlistId: playlistId, name: name);
    return _validateAndPromote(parsed, previous);
  }

  Future<PlaylistImportResult> importRemote({
    required Uri uri,
    required String playlistId,
    required String name,
    Playlist? previous,
  }) async {
    if (!await urlPolicy.acceptsResolved(uri)) {
      throw const FormatException(
          'URL de playlist no permitida o apunta a una red local');
    }

    await _stateRepository?.markUpdating(playlistId, uri);
    try {
      final response = await _client.send(http.Request('GET', uri));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FormatException(
          'La playlist respondió HTTP ${response.statusCode}',
        );
      }

      final lines = <String>[];
      var characters = 0;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        characters += line.length + 1;
        if (characters > parser.maxContentCharacters) {
          throw const M3uParseException('Playlist content limit exceeded');
        }
        if (line.length > parser.maxLineLength) {
          throw const M3uParseException('Playlist line limit exceeded');
        }
        lines.add(line);
      }

      if (lines.isEmpty) {
        throw const FormatException('La playlist remota está vacía');
      }

      final parsed =
          parser.parseLines(lines, playlistId: playlistId, name: name);
      final result = _validateAndPromote(parsed, previous, sourceUri: uri);
      await _stateRepository?.markActive(
          playlistId, uri, parsed.rawContentHash);
      return result;
    } catch (error) {
      await _stateRepository?.markFailed(playlistId, uri, error.toString());
      rethrow;
    }
  }

  PlaylistImportResult _validateAndPromote(
    Playlist parsed,
    Playlist? previous, {
    Uri? sourceUri,
  }) {
    final validation = validator.validate(parsed);
    if (!validation.valid) {
      throw FormatException(validation.reason);
    }
    if (previous != null && previous.rawContentHash == parsed.rawContentHash) {
      return PlaylistImportResult(playlist: previous, replaced: false);
    }
    return PlaylistImportResult(
      playlist: Playlist(
        id: parsed.id,
        name: parsed.name,
        entries: parsed.entries,
        sourceUri: sourceUri ?? previous?.sourceUri,
        rawContentHash: parsed.rawContentHash,
        updatedAt: DateTime.now(),
      ),
      replaced: true,
    );
  }

  void dispose() => _client.close();
}
