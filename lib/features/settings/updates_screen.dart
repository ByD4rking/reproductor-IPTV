import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/updates/app_update_service.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final _service = AppUpdateService();
  UpdateCheckResult? _result;
  bool _checking = false;
  bool _installing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await _service.checkForUpdate();
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _install() async {
    final info = _result?.info;
    if (info == null || !info.hasUpdate || _installing) return;
    setState(() {
      _installing = true;
      _error = null;
    });
    try {
      await _service.downloadAndInstall(info);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'APK verificada. Completa la actualización en el instalador de Android.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.length > 400 ? '${message.substring(0, 400)}…' : message;
  }

  @override
  Widget build(BuildContext context) {
    final info = _result?.info;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return Scaffold(
      appBar: AppBar(title: const Text('Actualizaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.system_update_alt, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Actualización de la aplicación',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!android)
                    const Text(
                      'La instalación integrada de APK está disponible solo en Android. '
                      'En otras plataformas, las actualizaciones se distribuyen por su método correspondiente.',
                    )
                  else if (_checking)
                    const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('Buscando la última versión oficial…')),
                      ],
                    )
                  else if (info != null) ...[
                    Text('Instalada: ${info.installedVersion}'),
                    const SizedBox(height: 4),
                    Text('Última publicada: ${info.latestVersion}'),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          info.status == UpdateStatus.available
                              ? Icons.new_releases_outlined
                              : info.status == UpdateStatus.current
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            info.status == UpdateStatus.available
                                ? 'Hay una versión nueva disponible.'
                                : info.message ?? 'Estado de actualización no disponible.',
                          ),
                        ),
                      ],
                    ),
                    if (info.releaseNotes.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Notas de la versión',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        info.releaseNotes.length > 3500
                            ? '${info.releaseNotes.substring(0, 3500)}…'
                            : info.releaseNotes,
                      ),
                    ],
                    if (info.hasUpdate) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _installing ? null : _install,
                          icon: _installing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _installing
                                ? 'Descargando y verificando APK…'
                                : 'Descargar e instalar actualización',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Se verifica el SHA-256 del APK antes de abrir el instalador. '
                        'Android puede pedir permiso para instalar desde esta aplicación y siempre requiere confirmar la instalación.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ] else if (_error == null)
                    const Text('Pulsa “Buscar actualizaciones” para comprobar la versión.'),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: !android || _checking || _installing ? null : _check,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Buscar actualizaciones'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Descarga verificada'),
            subtitle: Text(
              'La app solo acepta APK de la Release oficial del repositorio y compara su SHA-256 con el digest publicado por GitHub.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.save_outlined),
            title: Text('Tus listas se conservan'),
            subtitle: Text(
              'La actualización sustituye la aplicación mediante Android. No elimina las listas ni los ajustes guardados en el almacenamiento privado de la app.',
            ),
          ),
        ],
      ),
    );
  }
}
