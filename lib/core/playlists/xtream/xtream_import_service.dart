import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';
import '../../network/url_policy.dart';

class XtreamException implements Exception {
  const XtreamException(this.message);

  final String message;

  @override
  String toString() => message;
}

class XtreamImportService {
  XtreamImportService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.urlPolicy = const UrlPolicy(),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;
  final UrlPolicy urlPolicy;

  Future<Playlist> importLiveChannels({
    required Uri server,
    required String username,
    required String password,
    String? playlistName,
  }) async {
    final base = _normalizeServer(server);
    if (username.trim().isEmpty || password.isEmpty) {
      throw const XtreamException('Usuario y contraseña son obligatorios.');
    }
    if (!await urlPolicy.acceptsResolved(base)) {
      throw const XtreamException(
        'El servidor Xtream no está permitido o apunta a una red local.',
      );
    }

    final categories = await _getJsonList(
      _apiUri(base, username, password, 'get_live_categories'),
      'categorías',
    );
    final streams = await _getJsonList(
      _apiUri(base, username, password, 'get_live_streams'),
      'canales en directo',
    );

    final categoryNames = <String, String>{
      for (final value in categories)
        if (value is Map<String, dynamic>)
          if (value['category_id'] != null)
            value['category_id'].toString():
                (value['category_name'] ?? 'Otros').toString(),
    };

    final entries = <PlaylistEntry>[];
    for (final raw in streams) {
      if (raw is! Map<String, dynamic>) continue;

      final streamId = raw['stream_id']?.toString();
      final name = (raw['name'] ?? '').toString().trim();
      if (streamId == null || streamId.isEmpty || name.isEmpty) continue;

      final uri = _streamUri(base, username, password, streamId);
      if (!urlPolicy.accepts(uri) || uri.host != base.host) continue;

      final iconText = raw['stream_icon']?.toString();
      final icon =
          iconText == null || iconText.isEmpty ? null : Uri.tryParse(iconText);
      final safeIcon = icon != null &&
              urlPolicy.accepts(icon) &&
              icon.host == base.host
          ? icon
          : null;

      final categoryId = raw['category_id']?.toString();
      final category =
          categoryId == null ? null : categoryNames[categoryId];

      final epgId = raw['epg_channel_id']?.toString();
      final channelId =
          epgId != null && epgId.isNotEmpty ? epgId : 'xtream:$streamId';

      entries.add(
        PlaylistEntry(
          id: 'xtream:$streamId',
          channel: Channel(
            id: channelId,
            displayName: name,
            tvgId: epgId,
          ),
          category: category,
          logoUrl: safeIcon,
          sources: [
            StreamSource(
              id: 'xtream:$streamId:hls',
              url: uri,
            ),
          ],
        ),
      );

      if (entries.length >= 100000) break;
    }

    if (entries.isEmpty) {
      throw const XtreamException(
        'Xtream respondió correctamente, pero no devolvió canales utilizables.',
      );
    }

    return Playlist(
      id: 'xtream-${DateTime.now().microsecondsSinceEpoch}',
      name: playlistName?.trim().isEmpty ?? true
          ? 'Xtream · ${base.host}'
          : playlistName!.trim(),
      entries: List.unmodifiable(entries),
      sourceUri: base,
      updatedAt: DateTime.now(),
    );
  }

  Uri _normalizeServer(Uri value) {
    var path = value.path;
    const suffix = '/player_api.php';
    if (path.endsWith(suffix)) {
      path = path.substring(0, path.length - suffix.length);
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) path = '/';
    if (!path.endsWith('/')) path = '$path/';

    return value.replace(
      path: path,
      query: null,
      fragment: null,
      userInfo: '',
    );
  }

  Uri _apiUri(
    Uri base,
    String username,
    String password,
    String action,
  ) {
    final query = <String, String>{
      'username': username,
      'password': password,
      'action': action,
    };
    return base.resolve(
      'player_api.php?${_encodeQuery(query)}',
    );
  }

  Uri _streamUri(
    Uri base,
    String username,
    String password,
    String streamId,
  ) {
    final encodedUser = Uri.encodeComponent(username);
    final encodedPassword = Uri.encodeComponent(password);
    final encodedId = Uri.encodeComponent(streamId);
    return base.resolve(
      'live/$encodedUser/$encodedPassword/$encodedId.m3u8',
    );
  }

  String _encodeQuery(Map<String, String> values) => values.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');

  Future<List<dynamic>> _getJsonList(Uri uri, String label) async {
    if (!await urlPolicy.acceptsResolved(uri)) {
      throw XtreamException('URL de $label no permitida.');
    }

    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw XtreamException(
        'El servidor Xtream respondió HTTP ${response.statusCode} al solicitar $label.',
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['error'] != null) {
        throw XtreamException('Xtream rechazó la solicitud de $label.');
      }
      throw XtreamException('Respuesta Xtream inválida para $label.');
    } on FormatException {
      throw XtreamException(
        'El servidor Xtream devolvió JSON inválido para $label.',
      );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
