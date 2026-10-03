import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/playlists/repository/remote_playlist_state_repository.dart';

void main() {
  test('remote playlist status preserves last known good hash', () {
    final status = RemotePlaylistStatus(
      playlistId: 'p1',
      state: RemotePlaylistState.failed,
      updatedAt: DateTime.utc(2026, 10, 3),
      uri: Uri.parse('https://example.com/list.m3u'),
      lastGoodHash: 'good-hash',
      lastError: 'temporary failure',
    );

    final decoded = RemotePlaylistStatus.fromJson(status.toJson());

    expect(decoded.playlistId, 'p1');
    expect(decoded.state, RemotePlaylistState.failed);
    expect(decoded.lastGoodHash, 'good-hash');
    expect(decoded.lastError, 'temporary failure');
  });
}
