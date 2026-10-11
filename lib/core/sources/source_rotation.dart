/// Deterministic fallback rotation that never selects the current source.
///
/// Recovery begins by excluding the source that just failed, then visits each
/// remaining playlist source at most once in that recovery pass.
class SourceRotation {
  const SourceRotation._();

  static int nextIndex({required int currentIndex, required int sourceCount}) {
    if (sourceCount <= 0) return 0;
    final normalized = currentIndex % sourceCount;
    return (normalized + 1) % sourceCount;
  }
}
