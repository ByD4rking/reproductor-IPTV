import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VideoLibraryItem {
  const VideoLibraryItem({
    required this.id,
    required this.title,
    required this.url,
    this.category = 'Vídeos',
    this.posterUrl,
  });

  final String id;
  final String title;
  final Uri url;
  final String category;
  final Uri? posterUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url.toString(),
        'category': category,
        if (posterUrl != null) 'posterUrl': posterUrl.toString(),
      };

  static VideoLibraryItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final raw = json['url'];
    if (id is! String || id.isEmpty || title is! String || title.trim().isEmpty || raw is! String) {
      return null;
    }
    final url = Uri.tryParse(raw);
    if (url == null || !{'http', 'https'}.contains(url.scheme.toLowerCase())) {
      return null;
    }
    final poster = json['posterUrl'];
    final posterUrl = poster is String ? Uri.tryParse(poster) : null;
    return VideoLibraryItem(
      id: id,
      title: title.trim(),
      url: url,
      category: json['category'] is String && (json['category'] as String).trim().isNotEmpty
          ? (json['category'] as String).trim()
          : 'Vídeos',
      posterUrl: posterUrl,
    );
  }
}

class VideoLibraryRepository {
  static const _key = 'video_library_v1';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  Future<void> _writeQueue = Future<void>.value();

  Future<List<VideoLibraryItem>> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => VideoLibraryItem.fromJson(Map<String, dynamic>.from(item)))
          .whereType<VideoLibraryItem>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<VideoLibraryItem> items) => _enqueue(() async {
        await _preferences.setString(
          _key,
          jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
        );
      });

  Future<void> upsert(VideoLibraryItem item) => _enqueue(() async {
        final items = [...await load()];
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) {
          items[index] = item;
        } else {
          items.add(item);
        }
        await _preferences.setString(
          _key,
          jsonEncode(items.map((entry) => entry.toJson()).toList(growable: false)),
        );
      });

  Future<void> remove(String id) => _enqueue(() async {
        final items = await load();
        await _preferences.setString(
          _key,
          jsonEncode(items.where((entry) => entry.id != id).map((entry) => entry.toJson()).toList(growable: false)),
        );
      });

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _writeQueue.then((_) => operation());
    _writeQueue = next.catchError((_) {});
    return next;
  }
}
