import '../../domain/entities/channel.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/stream_source.dart';

class M3uParseException implements Exception { const M3uParseException(this.message); final String message; }

class M3uParser {
  const M3uParser({this.maxChannels=100000, this.maxLineLength=1048576});
  final int maxChannels;
  final int maxLineLength;

  Playlist parse(String content, {String playlistId='imported', String name='Imported'}) {
    if (content.length > maxChannels * maxLineLength) throw const M3uParseException('Playlist exceeds size limit');
    final entries=<PlaylistEntry>[];
    String? info;
    var attrs=<String,String>{};
    var index=0;
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      if (raw.length > maxLineLength) throw const M3uParseException('Line exceeds size limit');
      final line=raw.trim();
      if (line.isEmpty || line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#EXTINF:')) {
        final comma=line.indexOf(',');
        if (comma < 0) { info=''; attrs={}; continue; }
        info=line.substring(comma+1).trim();
        attrs=_attrs(line.substring(8, comma));
        continue;
      }
      if (line.startsWith('#')) continue;
      final uri=Uri.tryParse(line);
      if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) { info=null; attrs={}; continue; }
      final nameValue=(info == null || info!.isEmpty) ? uri.host : info!;
      final tvg=attrs['tvg-id'];
      final channelId=tvg == null || tvg.isEmpty ? 'name:'+Channel.normalizeIdentity(nameValue)+':'+index.toString() : 'tvg:'+tvg;
      entries.add(PlaylistEntry(
        id:'entry-'+index.toString(),
        channel:Channel(id:channelId, displayName:nameValue, tvgId:tvg, country:attrs['tvg-country'], language:attrs['tvg-language']),
        sources:[StreamSource(id:'source-'+index.toString(), url:uri, userAgent:attrs['http-user-agent'])],
        category:attrs['group-title'],
        logoUrl:_safeUri(attrs['tvg-logo']),
      ));
      index++;
      if (entries.length > maxChannels) throw const M3uParseException('Playlist exceeds channel limit');
      info=null; attrs={};
    }
    return Playlist(id:playlistId, name:name, entries:List.unmodifiable(entries));
  }

  Map<String,String> _attrs(String input) {
    final out=<String,String>{};
    final regex=RegExp(r'([A-Za-z0-9_-]+)=(?:"([^"]*)"|([^\s]+))');
    for (final m in regex.allMatches(input)) out[m.group(1)!]=m.group(2) ?? m.group(3) ?? '';
    return out;
  }
  Uri? _safeUri(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri=Uri.tryParse(value);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https')) ? uri : null;
  }
}
