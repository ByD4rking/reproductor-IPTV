import '../domain/entities/channel.dart';

class SearchIndex {
  final Map<String, Channel> _channels = <String, Channel>{};

  void clear() => _channels.clear();
  void add(Channel channel) => _channels[channel.id] = channel;

  void addAll(Iterable<Channel> channels) {
    for (final channel in channels) {
      add(channel);
    }
  }

  void replace(Iterable<Channel> channels) {
    clear();
    addAll(channels);
  }

  List<Channel> query(String text, {int limit = 50}) {
    final needle = Channel.normalizeIdentity(text);
    if (needle.isEmpty || limit <= 0) return const <Channel>[];
    final matches = _channels.values.where((channel) {
      final name = channel.normalizedName;
      final id = Channel.normalizeIdentity(channel.tvgId ?? '');
      return name.contains(needle) || id.contains(needle);
    }).toList();
    matches.sort((a, b) {
      final an = a.normalizedName;
      final bn = b.normalizedName;
      final aExact = an == needle;
      final bExact = bn == needle;
      if (aExact != bExact) return aExact ? -1 : 1;
      final aPrefix = an.startsWith(needle);
      final bPrefix = bn.startsWith(needle);
      if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
      return an.compareTo(bn);
    });
    return matches.take(limit).toList(growable: false);
  }

  List<Channel> search(String text, {int limit = 50}) =>
      query(text, limit: limit);
}
