import '../../domain/entities/playlist.dart';

class PlaylistValidationResult { const PlaylistValidationResult({required this.valid, required this.reason}); final bool valid; final String reason; }
class PlaylistValidator {
  const PlaylistValidator();
  PlaylistValidationResult validate(Playlist playlist) {
    if (playlist.entries.isEmpty) return const PlaylistValidationResult(valid:false, reason:'Playlist contains no playable entries');
    for (final entry in playlist.entries) {
      if (entry.sources.isEmpty) return PlaylistValidationResult(valid:false, reason:'Entry '+entry.id+' has no source');
      for (final source in entry.sources) {
        if (!(source.url.isScheme('http') || source.url.isScheme('https'))) return PlaylistValidationResult(valid:false, reason:'Unsupported URL scheme');
      }
    }
    return const PlaylistValidationResult(valid:true, reason:'ok');
  }
}
