import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.autoRecovery = true,
    this.autoSourceSwitching = true,
  });
  final bool autoRecovery;
  final bool autoSourceSwitching;
}

class SettingsRepository {
  SettingsRepository({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const _recovery = 'settings.autoRecovery';
  static const _switching = 'settings.autoSourceSwitching';

  Future<AppSettings> load() async => AppSettings(
    autoRecovery: await _preferences.getBool(_recovery) ?? true,
    autoSourceSwitching: await _preferences.getBool(_switching) ?? true,
  );

  Future<void> save(AppSettings settings) async {
    await _preferences.setBool(_recovery, settings.autoRecovery);
    await _preferences.setBool(_switching, settings.autoSourceSwitching);
  }
}
