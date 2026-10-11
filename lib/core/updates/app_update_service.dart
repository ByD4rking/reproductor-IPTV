import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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
    http.Client? client,
    Future<PackageInfo> Function()? packageInfoLoader,
    Future<Directory> Function()? directoryLoader,
    Future<bool> Function()? canInstallLoader,
    Future<bool> Function()? requestInstallPermission,
    Future<void> Function(String path)? installer,
    this.repository = 'ByD4rking/reproductor-IPTV',
  })  : _client = client ?? http.Client(),
        _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform,
        _directoryLoader = directoryLoader ?? getTemporaryDirectory,
        _canInstallLoader = canInstallLoader ?? _defaultCanInstall,
        _requestInstallPermission =
            requestInstallPermission ?? _defaultRequestInstallPermission,
        _installer = installer ?? _defaultInstaller;

  final http.Client _client;
  final Future<PackageInfo> Function() _packageInfoLoader;
  final Future<Directory> Function() _directoryLoader;
  final Future<bool> Function() _canInstallLoader;
  final Future<bool> Function() _requestInstallPermission;
  final Future<void> Function(String path) _installer;
  final String repository;

  static const _releaseEndpoint =
      'https://api.github.com/repos/ByD4rking/reproductor-IPTV/releases/latest';
  static const _maxApkBytes = 250 * 1024 * 1024;

  Future<UpdateCheckResult> checkForUpdate() async {
    final package = await _packageInfoLoader();
    final response = await _client.get(
      Uri.parse(_releaseEndpoint),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ).timeout(const Duration(seconds: 25));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('GitHub respondió HTTP ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de Release inválida.');
    }
    final tag = decoded['tag_name'];
    if (tag is! String || tag.trim().isEmpty) {
      throw const FormatException('La Release no tiene tag_name.');
    }
    final latestVersion = _normalizeVersion(tag);
    final installedVersion = _normalizeVersion(package.version);
    final releaseUrl = Uri.tryParse(decoded['html_url']?.toString() ?? '');
    if (releaseUrl == null ||
        releaseUrl.scheme != 'https' ||
        releaseUrl.host != 'github.com' ||
        releaseUrl.pathSegments.length < 4 ||
        releaseUrl.pathSegments[0] != repository.split('/')[0] ||
        releaseUrl.pathSegments[1] != repository.split('/')[1] ||
        releaseUrl.pathSegments[2] != 'releases' ||
        releaseUrl.pathSegments[3] != 'tag') {
      throw const FormatException('URL de Release no confiable.');
    }

    final assetsRaw = decoded['assets'];
    final assets = assetsRaw is List ? assetsRaw : const [];
    final selected = _selectApkAsset(assets);
    final notes = (decoded['body'] ?? '').toString();
    final comparison = _compareVersions(latestVersion, installedVersion);
    if (comparison <= 0) {
      return UpdateCheckResult(
        releaseUrl: releaseUrl,
        info: AppUpdateInfo(
          status: UpdateStatus.current,
          installedVersion: package.version,
          latestVersion: latestVersion,
          releaseNotes: notes,
          message: comparison == 0
              ? 'Ya tienes la última versión publicada.'
              : 'La Release publicada es anterior a la versión instalada.',
        ),
      );
    }
    if (selected == null) {
      return UpdateCheckResult(
        releaseUrl: releaseUrl,
        info: AppUpdateInfo(
          status: UpdateStatus.unsupported,
          installedVersion: package.version,
          latestVersion: latestVersion,
          releaseNotes: notes,
          message: 'La Release no contiene un APK Android compatible.',
        ),
      );
    }
    final browserUrl = Uri.tryParse(selected['browser_download_url']?.toString() ?? '');
    final name = selected['name']?.toString() ?? '';
    final size = selected['size'];
    if (browserUrl == null ||
        browserUrl.scheme != 'https' ||
        browserUrl.host != 'github.com' ||
        !browserUrl.path.startsWith('/${repository}/releases/download/') ||
        !name.endsWith('.apk') ||
        size is! num ||
        size <= 0 ||
        size > _maxApkBytes) {
      throw const FormatException('El asset APK no supera las validaciones.');
    }
    final digest = selected['digest']?.toString() ?? '';
    final sha = digest.startsWith('sha256:') ? digest.substring(7) : '';
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha)) {
      throw const FormatException('La Release no publica un SHA-256 válido.');
    }

    return UpdateCheckResult(
      releaseUrl: releaseUrl,
      info: AppUpdateInfo(
        status: UpdateStatus.available,
        installedVersion: package.version,
        latestVersion: latestVersion,
        releaseNotes: notes,
        assetName: name,
        downloadUrl: browserUrl,
        sha256: sha.toLowerCase(),
      ),
    );
  }

  Future<void> downloadAndInstall(AppUpdateInfo info) async {
    if (!info.hasUpdate ||
        info.downloadUrl == null ||
        info.sha256 == null ||
        info.assetName == null) {
      throw StateError('No hay un APK verificado disponible para instalar.');
    }
    final directory = await _directoryLoader();
    final safeName = info.assetName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${directory.path}/update-${safeName}');
    if (await file.exists()) await file.delete();

    final request = http.Request('GET', info.downloadUrl!);
    final response = await _client.send(request).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Descarga del APK falló: HTTP ${response.statusCode}.');
    }
    final declaredLength = response.contentLength;
    if (declaredLength != null &&
        (declaredLength <= 0 || declaredLength > _maxApkBytes)) {
      throw const FormatException('Tamaño de APK no válido.');
    }
    final sink = file.openWrite();
    final hashSink = AccumulatorSink<Digest>();
    final hashConverter = sha256.startChunkedConversion(hashSink);
    var bytes = 0;
    try {
      await for (final chunk in response.stream) {
        bytes += chunk.length;
        if (bytes > _maxApkBytes) {
          throw const FormatException('El APK supera el tamaño máximo.');
        }
        hashConverter.add(chunk);
        sink.add(chunk);
      }
      hashConverter.close();
      await sink.flush();
      await sink.close();
    } catch (_) {
      hashConverter.close();
      await sink.close();
      if (await file.exists()) await file.delete();
      rethrow;
    }
    if (bytes == 0 || (declaredLength != null && bytes != declaredLength)) {
      if (await file.exists()) await file.delete();
      throw const FormatException('La descarga del APK quedó incompleta.');
    }
    if (hashSink.events.single.toString().toLowerCase() != info.sha256) {
      if (await file.exists()) await file.delete();
      throw const FormatException('El SHA-256 del APK no coincide con GitHub.');
    }

    if (!await _canInstallLoader()) {
      final granted = await _requestInstallPermission();
      if (!granted) {
        throw StateError(
          'Android requiere permiso para instalar aplicaciones de esta fuente. '
          'Actívalo y vuelve a pulsar Instalar actualización.',
        );
      }
    }
    await _installer(file.path);
  }

  Map<String, dynamic>? _selectApkAsset(List assets) {
    final apkAssets = assets.whereType<Map<String, dynamic>>().where((asset) {
      final name = asset['name']?.toString() ?? '';
      return name.toLowerCase().endsWith('.apk');
    }).toList();
    if (apkAssets.isEmpty) return null;
    final preferred = apkAssets.where((asset) {
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      return name.contains('android-universal.apk') &&
          !name.contains('androidtv') &&
          !name.contains('firetv');
    }).toList();
    if (preferred.isNotEmpty) return preferred.first;
    final universal = apkAssets.where((asset) {
      final name = (asset['name']?.toString() ?? '').toLowerCase();
      return name.contains('android') && name.contains('universal');
    }).toList();
    return universal.isEmpty ? null : universal.first;
  }

  static String _normalizeVersion(String raw) {
    final value = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:[+-].*)?$').firstMatch(value);
    if (match == null) {
      throw FormatException('Versión no compatible: $raw');
    }
    return '${int.parse(match.group(1)!)}.${int.parse(match.group(2)!)}.${int.parse(match.group(3)!)}';
  }

  static int _compareVersions(String left, String right) {
    final a = left.split('.').map(int.parse).toList();
    final b = right.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return 0;
  }

  static Future<bool> _defaultCanInstall() async {
    if (!Platform.isAndroid) return false;
    return false;
  }

  static Future<bool> _defaultRequestInstallPermission() async {
    throw UnsupportedError(
      'El permiso de instalación de Android requiere integración nativa.',
    );
  }

  static Future<void> _defaultInstaller(String path) async {
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw StateError('No se pudo abrir el instalador: ${result.message}');
    }
  }
}
