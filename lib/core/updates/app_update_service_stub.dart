enum UpdateStatus { current, available, unsupported, failed }

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.status,
    required this.installedVersion,
    required this.latestVersion,
    required this.releaseNotes,
    this.assetName,
    this.downloadUrl,
    this.sha256,
    this.message,
  });

  final UpdateStatus status;
  final String installedVersion;
  final String latestVersion;
  final String releaseNotes;
  final String? assetName;
  final Uri? downloadUrl;
  final String? sha256;
  final String? message;
  bool get hasUpdate => status == UpdateStatus.available;
}

class UpdateCheckResult {
  const UpdateCheckResult({required this.info, required this.releaseUrl});
  final AppUpdateInfo info;
  final Uri releaseUrl;
}

class AppUpdateService {
  AppUpdateService({
    String repository = 'ByD4rking/reproductor-IPTV',
    Object? client,
    Future<Object?> Function()? packageInfoLoader,
    Future<Object?> Function()? directoryLoader,
    Future<bool> Function()? canInstallLoader,
    Future<bool> Function()? requestInstallPermission,
    Future<void> Function(String path)? installer,
    Future<String> Function()? profileLoader,
  });

  Future<UpdateCheckResult> checkForUpdate() {
    throw UnsupportedError(
      'La comprobación e instalación de APK solo está disponible en Android.',
    );
  }

  Future<void> downloadAndInstall(AppUpdateInfo info) {
    throw UnsupportedError(
      'La instalación integrada de APK solo está disponible en Android.',
    );
  }
}
