import '../../domain/entities/playlist.dart';

class PlaylistValidationResult {\n  const PlaylistValidationResult({required this.valid, required this.reason});\n\n  final bool valid;\n  final String reason;\n}
class PlaylistValidator {
  const PlaylistValidator();
  PlaylistValidationResult validate(Playlist playlist) {
    if (playlist.entries.isEmpty) {\n      return const PlaylistValidationResult(\n        valid: false,\n        reason: 'Playlist contains no playable entries',\n      );\n    }
    for (final entry in playlist.entries) {
      if (entry.sources.isEmpty) {\n        return PlaylistValidationResult(\n          valid: false,\n          reason: 'Entry ' + entry.id + ' has no source',\n        );\n      }
      for (final source in entry.sources) {
        if (!(source.url.isScheme('http') ||\n            source.url.isScheme('https'))) {\n          return const PlaylistValidationResult(\n            valid: false,\n            reason: 'Unsupported URL scheme',\n          );\n        }
      }
    }
    return const PlaylistValidationResult(valid: true, reason: 'ok');
  }
}
