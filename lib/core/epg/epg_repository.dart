import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'epg_matcher.dart';
import 'xmltv/xmltv_parser.dart';
import '../storage/atomic_string_list_store.dart';
import '../network/url_policy.dart';

class EpgRepository {
  EpgRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'epg.v1';
  final AtomicStringListStore _store;
  final _preferences = SharedPreferencesAsync();
  static const _sourceUrlKey = 'epg.source_url.v1';
  static const _maxXmltvBytes = 16 * 1024 * 1024;
  List<EpgProgramme>? _cache;

  Future<List<EpgProgramme>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final raw = await _store.load();
    final values = _decodeList(raw);
    _cache = values;
    return List.unmodifiable(values);
  }

  Future<int> importXmltv(String xml) async {
    final parsed = const XmltvParser().parse(xml);
    if (parsed.isEmpty) {
      throw const FormatException('El XMLTV no contiene programas válidos');
    }
    final encoded = parsed
        .map((value) => jsonEncode(_encode(value)))
        .toList(growable: false);
    await _store.save(encoded);
    _cache = parsed;
    return parsed.length;
  }

  Future<int> importXmltvUrl(Uri uri, {Duration timeout = const Duration(seconds: 15)}) async {
    const policy = UrlPolicy();
    if (!await policy.acceptsResolved(uri)) {
      throw const FormatException('URL XMLTV no permitida o apunta a una red local');
    }
    final response = await http.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException('El XMLTV respondió HTTP ${response.statusCode}');
    }
    if (response.bodyBytes.length > _maxXmltvBytes) {
      throw const FormatException('El XMLTV supera el límite de 16 MiB');
    }
    final count = await importXmltv(utf8.decode(response.bodyBytes, allowMalformed: false));
    await _preferences.setString(_sourceUrlKey, uri.toString());
    return count;
  }

  Future<Uri?> sourceUrl() async {
    final value = await _preferences.getString(_sourceUrlKey);
    if (value == null || value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  Future<int?> refreshConfigured() async {
    final uri = await sourceUrl();
    if (uri == null) return null;
    return importXmltvUrl(uri);
  }

  Future<void> clear() async {
    _cache = const <EpgProgramme>[];
    await _store.clear();
  }

  Map<String, dynamic> _encode(EpgProgramme value) => {
        'id': value.id,
        'channelId': value.channelId,
        'title': value.title,
        'start': value.start.toIso8601String(),
        'end': value.end.toIso8601String(),
      };

  List<EpgProgramme> _decodeList(List<String> raw) {
    final values = <EpgProgramme>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        values.add(EpgProgramme(
          id: map['id'] as String,
          channelId: map['channelId'] as String,
          title: map['title'] as String,
          start: DateTime.parse(map['start'] as String),
          end: DateTime.parse(map['end'] as String),
        ));
      } catch (_) {}
    }
    return values;
  }
}
