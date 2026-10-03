class Channel {
  const Channel({required this.id, required this.displayName, this.tvgId, this.country, this.language});
  final String id;
  final String displayName;
  final String? tvgId;
  final String? country;
  final String? language;
  String get normalizedName => normalizeIdentity(displayName);
  static String normalizeIdentity(String value) => value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
