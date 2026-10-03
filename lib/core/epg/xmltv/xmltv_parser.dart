import '../epg_matcher.dart';

class XmltvParseException implements Exception { const XmltvParseException(this.message); final String message; }

class XmltvParser {
  const XmltvParser({this.maxProgrammes=500000});
  final int maxProgrammes;

  List<EpgProgramme> parse(String xml) {
    final programmes=<EpgProgramme>[];
    final tag=RegExp(r'<programme\b([^>]*)>(.*?)</programme>', dotAll:true);
    for (final match in tag.allMatches(xml)) {
      if (programmes.length >= maxProgrammes) throw const XmltvParseException('EPG programme limit exceeded');
      final attrs=_attrs(match.group(1) ?? '');
      final channel=attrs['channel'];
      final start=_time(attrs['start']);
      final end=_time(attrs['stop']);
      final title=_text(match.group(2) ?? 'title');
      if (channel == null || start == null || end == null || title.isEmpty) continue;
      programmes.add(EpgProgramme(id:channel+'@'+start.toIso8601String(), channelId:channel, title:title, start:start, end:end));
    }
    return List.unmodifiable(programmes);
  }

  Map<String,String> _attrs(String input) {
    final out=<String,String>{};
    final regex=RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');
    for (final m in regex.allMatches(input)) out[m.group(1)!]=m.group(2)!;
    return out;
  }
  DateTime? _time(String? value) {
    if (value == null || value.length < 14) return null;
    final digits=value.substring(0,14);
    final parsed=DateTime.tryParse(digits.substring(0,4)+'-'+digits.substring(4,6)+'-'+digits.substring(6,8)+'T'+digits.substring(8,10)+':'+digits.substring(10,12)+':'+digits.substring(12,14));
    return parsed;
  }
  String _text(String body) {
    final m=RegExp(r'<title(?:\s[^>]*)?>(.*?)</title>', dotAll:true).firstMatch(body);
    if (m == null) return '';
    return m.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }
}
