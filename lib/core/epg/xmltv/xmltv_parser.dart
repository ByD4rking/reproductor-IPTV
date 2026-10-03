import '../epg_matcher.dart';

class XmltvParseException implements Exception {
  const XmltvParseException(this.message);
  final String message;

  @override
  String toString() => 'XmltvParseException: $message';
}

class XmltvParser {
  const XmltvParser({this.maxProgrammes = 500000});
  final int maxProgrammes;

  List<EpgProgramme> parse(String xml) {
    if (xml.length > 64 * 1024 * 1024) {
      throw const XmltvParseException('EPG document exceeds size limit');
    }

    final programmes = <EpgProgramme>[];
    final tag = RegExp(
      r'<programme\b([^>]*)>(.*?)</programme>',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in tag.allMatches(xml)) {
      if (programmes.length >= maxProgrammes) {
        throw const XmltvParseException('EPG programme limit exceeded');
      }

      final attrs = _attrs(match.group(1) ?? '');
      final channel = attrs['channel']?.trim();
      final start = _time(attrs['start']);
      final end = _time(attrs['stop']);
      final title = _text(match.group(2) ?? '');

      if (channel == null || channel.isEmpty || start == null || end == null || title.isEmpty) {
        continue;
      }
      if (!end.isAfter(start)) continue;

      programmes.add(
        EpgProgramme(
          id: '${channel}@${start.toIso8601String()}',
          channelId: channel,
          title: title,
          start: start,
          end: end,
        ),
      );
    }

    return List.unmodifiable(programmes);
  }

  Map<String, String> _attrs(String input) {
    final out = <String, String>{};
    final regex = RegExp(
      r'''([A-Za-z0-9_:-]+)\s*=\s*(["'])(.*?)\2''',
      dotAll: true,
    );
    for (final match in regex.allMatches(input)) {
      out[match.group(1)!] = match.group(3)!;
    }
    return out;
  }

  DateTime? _time(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?$',
    ).firstMatch(value.trim());
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);

    final sign = match.group(7);
    if (sign == null) return DateTime(year, month, day, hour, minute, second);

    final offset = Duration(
      hours: int.parse(match.group(8)!),
      minutes: int.parse(match.group(9)!),
    );
    final baseUtc = DateTime.utc(year, month, day, hour, minute, second);
    return sign == '+' ? baseUtc.subtract(offset) : baseUtc.add(offset);
  }

  String _text(String body) {
    final match = RegExp(
      r'<title(?:\s[^>]*)?>(.*?)</title>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return '';

    return _decodeEntities(
      match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
    );
  }

  String _decodeEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      );
}
