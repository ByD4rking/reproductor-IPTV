import 'package:http/http.dart' as http;

import '../../domain/entities/playlist.dart';
import '../../network/url_policy.dart';
import '../m3u/m3u_parser.dart';
import '../validator/playlist_validator.dart';

class PlaylistImportResult {
  const PlaylistImportResult({required this.playlist, required this.replaced});
  final Playlist playlist;
  final bool replaced;
}

class PlaylistImportService {
  const PlaylistImportService({
    this.parser = const M3uParser(),
    this.validator = const PlaylistValidator(),
    this.urlPolicy = const UrlPolicy(),
  });

  final M3uParser parser;
  final PlaylistValidator validator;
  final UrlPolicy urlPolicy;

  PlaylistImportResult importText({
    required String text,
    required String playlistId,
    required String name,
    Playlist? previous,
  }) {
    final parsed = parser.parse(text, playlistId: playlistId, name: name);
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
        rawContentHash: parsed.rawContentHash,
        updatedAt: DateTime.now(),
      ),
      replaced: true,
    );
  }

  Future<PlaylistImportResult> importRemote({
    required Uri uri,
    required String playlistId,
    required String name,
    Playlist? previous,
  }) async {
    if (!urlPolicy.accepts(uri)) {
      throw const FormatException('URL de playlist no permitida');
    }
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'La playlist respondió HTTP ' + response.statusCode.toString(),
      );
    }
    if (response.body.trim().isEmpty) {
      throw const FormatException('La playlist remota está vacía');
    }
    return importText(
      text: response.body,
      playlistId: playlistId,
      name: name,
      previous: previous,
    );
  }
}
