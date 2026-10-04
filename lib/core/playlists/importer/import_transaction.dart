import '../../domain/entities/playlist.dart';
import '../validator/playlist_validator.dart';

class ImportTransaction {
  const ImportTransaction(this.validator);
  final PlaylistValidator validator;

  Playlist commit({required Playlist previous, required Playlist candidate}) {
    final result = validator.validate(candidate);
    if (!result.valid) return previous;
    return candidate;
  }
}
