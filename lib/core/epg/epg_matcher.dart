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
    required String channelName,
    required Iterable<EpgProgramme> programmes,
  }) {
    final exactId = programmes.where((p) => p.channelId == channelId);
    final byId = _firstCurrentOrNext(exactId);
    if (byId != null) return byId;

    final normalizedName = _normalize(channelName);
    return _firstCurrentOrNext(
      programmes.where((p) => _normalize(p.title) == normalizedName),
    );
  }

  EpgProgramme? _firstCurrentOrNext(Iterable<EpgProgramme> values) {
    final now = DateTime.now();
    EpgProgramme? next;
    for (final programme in values) {
      if (!programme.end.isAfter(now)) continue;
      if (!programme.start.isAfter(now)) return programme;
      if (next == null || programme.start.isBefore(next.start)) next = programme;
    }
    return next;
  }

  String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
