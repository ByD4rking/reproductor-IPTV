class StallDetector {
  const StallDetector({this.minStall=const Duration(seconds:5), this.hardStall=const Duration(seconds:15)});
  final Duration minStall;
  final Duration hardStall;
  bool isStalled({required Duration lastProgressAge, required bool buffering, required bool dataArriving}) {
    if (!buffering && dataArriving) return false;
    return lastProgressAge >= minStall;
  }
  bool isHardStall(Duration lastProgressAge) => lastProgressAge >= hardStall;
}
