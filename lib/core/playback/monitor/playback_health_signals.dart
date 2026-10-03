class PlaybackHealthSignals {
  const PlaybackHealthSignals({
    required this.lastProgressAge,
    required this.bufferedAhead,
    required this.playheadMoving,
    required this.dataArriving,
    required this.networkActivity,
  });

  final Duration lastProgressAge;
  final Duration bufferedAhead;
  final bool playheadMoving;
  final bool dataArriving;
  final bool networkActivity;
}
