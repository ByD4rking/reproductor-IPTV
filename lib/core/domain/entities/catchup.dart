class CatchupWindow {
  const CatchupWindow({
    required this.start,
    required this.end,
    this.urlTemplate,
  });

  final DateTime start;
  final DateTime end;
  final String? urlTemplate;

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  bool get isValid => end.isAfter(start);
}
