import 'package:flutter/material.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';
import '../playlists/playlist_import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = SettingsRepository();
  final _playlists = PersistentPlaylistRepository();
  AppSettings _settings = const AppSettings();
  int _playlistCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    await _playlists.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _playlistCount = _playlists.playlists.length;
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
            onChanged: (value) =>
                _save(_settings.copyWith(autoRecovery: value)),
          ),
          SwitchListTile(
            value: _settings.autoSourceSwitching,
            title: const Text('Cambio automático de fuente'),
            subtitle: const Text(
                'Cambiar a otra fuente del mismo canal cuando corresponda.'),
            onChanged: (value) =>
                _save(_settings.copyWith(autoSourceSwitching: value)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Playlists guardadas'),
            subtitle: Text(
              '$_playlistCount listas almacenadas en los datos privados de la aplicación.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => PlaylistImportScreen(repository: _playlists),
                ),
              );

              // "Usar esta lista" returns the selected playlist id. This
              // screen previously discarded that result, so the playlist was
              // saved but never became the active playlist when the manager
              // was opened from Ajustes.
              if (selected != null && selected.isNotEmpty) {
                await _repository.setActivePlaylistId(selected);
              }

              await _playlists.load();
              final settings = await _repository.load();
              if (mounted) {
                setState(() {
                  _playlistCount = _playlists.playlists.length;
                  _settings = settings;
                });
              }
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Almacenamiento local'),
            subtitle: Text(
              'Las playlists locales se conservan al cerrar la aplicación y no dependen de la caché.',
            ),
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
