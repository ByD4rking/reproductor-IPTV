class EpgProgramme {
  const EpgProgramme({
    required this.id,
    required this.channelId,
    required this.title,
    required this.start,
    required this.end,
  });
  final String id;
  final String channelId;
  final String title;
  final DateTime start;
  final DateTime end;
}

class EpgMatcher {
  const EpgMatcher();

  EpgProgramme? match({
    required String channelId,
    String? channelName,
    String? tvgId,
    Iterable<String> aliases = const <String>[],
    required Iterable<EpgProgramme> programmes,
  }) {
    final channel = _normalize(channelId);
    final ids = <String>{
      channel,
      if (tvgId != null) _normalize(tvgId),
      ...aliases.map(_normalize),
    };
    final name = _normalize(channelName ?? channelId);
    final matching = <EpgProgramme>[];
    var bestScore = 0;
    for (final programme in programmes) {
      final candidate = _normalize(programme.channelId);
      var score = 0;
      if (candidate == channel) {
        score = 4;
      } else if (ids.contains(candidate)) {
        score = 3;
      } else if (candidate == name) {
        score = 2;
      }
      if (score > bestScore) {
        bestScore = score;
        matching
          ..clear()
          ..add(programme);
      } else if (score == bestScore && score > 0) {
        matching.add(programme);
      }
    }
    return bestScore == 0 ? null : _firstCurrentOrNext(matching);
  }

  EpgProgramme? _firstCurrentOrNext(Iterable<EpgProgramme> values) {
    final now = DateTime.now();
    EpgProgramme? next;
    for (final programme in values) {
      if (!programme.end.isAfter(now)) continue;
      if (!programme.start.isAfter(now)) return programme;
      if (next == null || programme.start.isBefore(next.start))
        next = programme;
    }
    return next;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}
