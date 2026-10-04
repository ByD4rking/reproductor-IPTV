abstract interface class PlaylistStorage {
  Future<Map<String, String>> load();
  Future<void> save(String id, String value);
  Future<void> remove(String id);
  Future<void> clear();
}
