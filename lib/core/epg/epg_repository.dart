import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'xmltv/xmltv_parser.dart';
import 'epg_matcher.dart';

class EpgRepository {
  EpgRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'epg.v1';
  final SharedPreferencesAsync _preferences;
  List<EpgProgramme>? _cache;

  Future<List<EpgProgramme>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final raw = await _preferences.getStringList(_key) ?? const <String>[];
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
    _cache = values;
    return List.unmodifiable(values);
  }

  Future<int> importXmltv(String xml) async {
    final parsed = const XmltvParser().parse(xml);
    if (parsed.isEmpty) throw const FormatException('El XMLTV no contiene programas válidos');
    _cache = parsed;
    await _preferences.setStringList(
      _key,
      parsed.map((p) => jsonEncode({
        'id': p.id,
        'channelId': p.channelId,
        'title': p.title,
        'start': p.start.toIso8601String(),
        'end': p.end.toIso8601String(),
      })).toList(),
    );
    return parsed.length;
  }

  Future<void> clear() async {
    _cache = const <EpgProgramme>[];
    await _preferences.setStringList(_key, const <String>[]);
  }
}
