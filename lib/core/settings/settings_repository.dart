import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.autoRecovery = true,
    this.autoSourceSwitching = true,
    this.activePlaylistId,
    this.demoSeeded = false,
  });

  final bool autoRecovery;
  final bool autoSourceSwitching;
  final String? activePlaylistId;
  final bool demoSeeded;
}

class SettingsRepository {
  SettingsRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _recovery = 'settings.autoRecovery';
  static const _switching = 'settings.autoSourceSwitching';
  static const _activePlaylist = 'settings.activePlaylistId';
  static const _demoSeeded = 'settings.demoSeeded';

  Future<AppSettings> load() async => AppSettings(
        autoRecovery: await _preferences.getBool(_recovery) ?? true,
        autoSourceSwitching: await _preferences.getBool(_switching) ?? true,
        activePlaylistId: await _preferences.getString(_activePlaylist),
        demoSeeded: await _preferences.getBool(_demoSeeded) ?? false,
      );

  Future<void> save(AppSettings settings) async {
    await _preferences.setBool(_recovery, settings.autoRecovery);
    await _preferences.setBool(_switching, settings.autoSourceSwitching);
    if (settings.activePlaylistId == null) {
      await _preferences.remove(_activePlaylist);
    } else {
      await _preferences.setString(
          _activePlaylist, settings.activePlaylistId!);
    }
    await _preferences.setBool(_demoSeeded, settings.demoSeeded);
  }

  Future<void> setActivePlaylistId(String? id) async {
    if (id == null) {
      await _preferences.remove(_activePlaylist);
    } else {
      await _preferences.setString(_activePlaylist, id);
    }
  }

  Future<void> markDemoSeeded() =>
      _preferences.setBool(_demoSeeded, true);
}
