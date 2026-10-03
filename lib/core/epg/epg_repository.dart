import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'epg_matcher.dart';
import 'xmltv/xmltv_parser.dart';

class EpgRepository {
  EpgRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _key = 'epg.v1';
  static const _lastGoodKey = 'epg.last-good.v1';
  final SharedPreferencesAsync _preferences;
  List<EpgProgramme>? _cache;

  Future<List<EpgProgramme>> load() async {
    if (_cache != null) return List.unmodifiable(_cache!);
    final raw = await _preferences.getStringList(_key) ??
        await _preferences.getStringList(_lastGoodKey) ??
        const <String>[];
    final values = _decodeList(raw);
    _cache = values;
    return List.unmodifiable(values);
  }

  Future<int> importXmltv(String xml) async {
    final parsed = const XmltvParser().parse(xml);
    if (parsed.isEmpty) {
      throw const FormatException(
        'El XMLTV no contiene programas válidos',
      );
    }
    final encoded = parsed.map(_encode).toList(growable: false);
    await _preferences.setStringList(_lastGoodKey, encoded);
    await _preferences.setStringList(_key, encoded);
    _cache = parsed;
    return parsed.length;
  }

  Future<void> clear() async {
    _cache = const <EpgProgramme>[];
    await _preferences.setStringList(_key, const <String>[]);
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