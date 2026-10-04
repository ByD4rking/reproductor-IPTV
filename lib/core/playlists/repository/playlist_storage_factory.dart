import 'playlist_storage.dart';
import 'playlist_storage_io.dart'
    if (dart.library.html) 'playlist_storage_web.dart';

PlaylistStorage createPlaylistStorage() => createPlaylistStorageImpl();
