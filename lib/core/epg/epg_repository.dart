import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'epg_matcher.dart';
import 'xmltv/xmltv_parser.dart';
import '../storage/atomic_string_list_store.dart';

class EpgRepository {
  EpgRepository({SharedPreferencesAsync? preferences})
      : _store = AtomicStringListStore(
          preferences: preferences ?? SharedPreferencesAsync(),
          key: _key,
        );

  static const _key = 'epg.v1';
  final AtomicStringListStore _store;
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
