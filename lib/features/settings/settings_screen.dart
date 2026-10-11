import 'package:flutter/material.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/playlists/repository/persistent_playlist_repository.dart';
import '../playlists/playlist_import_screen.dart';
import 'updates_screen.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tune_rounded,
                      size: 32, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('Controla tu experiencia',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          )),
                  const SizedBox(height: 6),
                  Text(
                    'Reproducción, listas y actualizaciones en un solo lugar.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('REPRODUCCIÓN',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    )),
          ),
          Card(
            child: Column(
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text('BIBLIOTECA Y SISTEMA',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    )),
          ),
          Card(
            child: Column(
              children: [
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Playlists'),
            subtitle: Text(
              'Administrar listas guardadas y cambiar la lista activa ($_playlistCount).',
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
                ListTile(
                  leading: const Icon(Icons.system_update_alt),
                  title: const Text('Actualizaciones'),
                  subtitle: const Text(
                    'Buscar, descargar y preparar la instalación de una nueva versión.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const UpdatesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.science_outlined),
            title: Text('reproductor-IPTV 0.3.0 · ALPHA'),
            subtitle: Text(
              'Versión de desarrollo. La reproducción y la estabilidad siguen en validación.',
            ),
          ),
          const Divider(),
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
