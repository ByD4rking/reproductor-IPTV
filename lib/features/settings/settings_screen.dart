import 'package:flutter/material.dart';
import '../../core/settings/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = SettingsRepository();
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _save(AppSettings settings) async {
    setState(() => _settings = settings);
    await _repository.save(settings);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          SwitchListTile(
            value: _settings.autoRecovery,
            title: const Text('Recuperación automática'),
            subtitle: const Text(
                'Detectar congelamientos y reintentar la reproducción.'),
            onChanged: (value) => _save(AppSettings(
              autoRecovery: value,
              autoSourceSwitching: _settings.autoSourceSwitching,
            )),
          ),
          SwitchListTile(
            value: _settings.autoSourceSwitching,
            title: const Text('Cambio automático de fuente'),
            subtitle: const Text(
                'Cambiar a otra fuente del mismo canal cuando corresponda.'),
            onChanged: (value) => _save(AppSettings(
              autoRecovery: _settings.autoRecovery,
              autoSourceSwitching: value,
            )),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.health_and_safety_outlined),
            title: Text('Diagnóstico'),
            subtitle: Text(
                'El reproductor registra salud de fuentes, recuperación y fallos localmente.'),
          ),
        ],
      ),
    );
  }
}
