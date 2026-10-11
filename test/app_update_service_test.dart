import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reproductor_iptv/core/updates/app_update_service.dart';

void main() {
  PackageInfo installed({String version = '0.3.0', String build = '1'}) =>
      PackageInfo(
        appName: 'Reproductor IPTV',
        packageName: 'com.reproductor.iptv',
        version: version,
        buildNumber: build,
        buildSignature: '',
      );

  Map<String, Object?> release({
    String tag = 'v0.3.0-build-269',
    String digest = 'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    List<Map<String, Object?>>? assets,
  }) =>
      {
        'tag_name': tag,
        'html_url':
            'https://github.com/ByD4rking/reproductor-IPTV/releases/tag/$tag',
        'body': 'Correcciones de estabilidad',
        'assets': assets ??
            [
              {
                'name': 'Reproductor-IPTV-0.3.0-Android-universal.apk',
                'size': 1000,
                'digest': digest,
                'browser_download_url':
                    'https://github.com/ByD4rking/reproductor-IPTV/releases/download/$tag/Reproductor-IPTV-0.3.0-Android-universal.apk',
              },
            ],
      };

  AppUpdateService service({
    required Map<String, Object?> releaseJson,
    String installedVersion = '0.3.0',
    String buildNumber = '1',
    String profile = 'mobile',
  }) {
    return AppUpdateService(
      client: MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        return http.Response(jsonEncode(releaseJson), 200);
      }),
      packageInfoLoader: () async =>
          installed(version: installedVersion, build: buildNumber),
      profileLoader: () async => profile,
    );
  }

  test('detects a newer build of the same semantic version', () async {
    final result = await service(releaseJson: release()).checkForUpdate();

    expect(result.info.status, UpdateStatus.available);
    expect(result.info.latestVersion, '0.3.0+269');
    expect(result.info.assetName, contains('Android-universal.apk'));
    expect(result.info.sha256, 'a' * 64);
  });

  test('reports current when the installed build matches the Release', () async {
    final result = await service(
      releaseJson: release(),
      buildNumber: '269',
    ).checkForUpdate();

    expect(result.info.status, UpdateStatus.current);
    expect(result.info.hasUpdate, isFalse);
  });

  test('rejects an APK asset without a SHA-256 digest', () async {
    await expectLater(
      service(releaseJson: release(digest: '')).checkForUpdate(),
      throwsFormatException,
    );
  });

  test('selects the APK matching an Android TV profile', () async {
    final tag = 'v0.4.0-build-270';
    final result = await service(
      profile: 'tv',
      releaseJson: release(
        tag: tag,
        assets: [
          {
            'name': 'Reproductor-IPTV-0.4.0-Android-universal.apk',
            'size': 1000,
            'digest': 'sha256:${'a' * 64}',
            'browser_download_url':
                'https://github.com/ByD4rking/reproductor-IPTV/releases/download/$tag/Reproductor-IPTV-0.4.0-Android-universal.apk',
          },
          {
            'name': 'Reproductor-IPTV-0.4.0-AndroidTV-GoogleTV-universal.apk',
            'size': 1000,
            'digest': 'sha256:${'b' * 64}',
            'browser_download_url':
                'https://github.com/ByD4rking/reproductor-IPTV/releases/download/$tag/Reproductor-IPTV-0.4.0-AndroidTV-GoogleTV-universal.apk',
          },
        ],
      ),
    ).checkForUpdate();

    expect(result.info.assetName, contains('AndroidTV-GoogleTV-universal.apk'));
    expect(result.info.sha256, 'b' * 64);
  });

  test('does not offer an update if the release has no universal APK', () async {
    final result = await service(
      releaseJson: release(assets: const []),
    ).checkForUpdate();

    expect(result.info.status, UpdateStatus.unsupported);
    expect(result.info.hasUpdate, isFalse);
  });
}
