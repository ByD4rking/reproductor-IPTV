import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/core/epg/xmltv/xmltv_parser.dart';

void main() {
  test('parses minimal XMLTV programme', () {
    const xml='<tv><programme channel="cnn.cl" start="20261003120000" stop="20261003130000"><title>Noticias</title></programme></tv>';
    final result=const XmltvParser().parse(xml);
    expect(result, hasLength(1));
    expect(result.first.channelId, 'cnn.cl');
    expect(result.first.title, 'Noticias');
  });
}
