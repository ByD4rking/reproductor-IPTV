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
    required Iterable<EpgProgramme> programmes,
  }) {
    return _firstCurrentOrNext(
      programmes.where((programme) => programme.channelId == channelId),
    );
  }

  EpgProgramme? _firstCurrentOrNext(Iterable<EpgProgramme> values) {
    final now = DateTime.now();
    EpgProgramme? next;

    for (final programme in values) {
      if (!programme.end.isAfter(now)) continue;
      if (!programme.start.isAfter(now)) return programme;
      if (next == null || programme.start.isBefore(next.start)) {
        next = programme;
      }
    }
    return next;
  }
}
