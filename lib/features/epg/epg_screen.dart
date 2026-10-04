import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/epg/epg_repository.dart';

class EpgScreen extends StatefulWidget {
  const EpgScreen({super.key});
  @override
  State<EpgScreen> createState() => _EpgScreenState();
}

class _EpgScreenState extends State<EpgScreen> {
  final _repository = EpgRepository();
  final _xml = TextEditingController();
  final _url = TextEditingController();
  Timer? _refreshTimer;
  bool _loading = true;
  bool _importing = false;
  List<dynamic> _programmes = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
    _refreshTimer =
        Timer.periodic(const Duration(hours: 6), (_) => _refreshRemote());
  }

  Future<void> _load() async {
    final values = await _repository.load();
    if (!mounted) return;
    setState(() {
      _programmes = values;
      _loading = false;
    });
  }

  Future<void> _refreshRemote() async {
    try {
      final count = await _repository.refreshConfigured();
      if (count != null && mounted) {
        await _load();
        if (mounted)
          setState(() => _message = 'EPG actualizado: $count programas');
      }
    } catch (error) {
      if (mounted) setState(() => _message = 'Error actualizando EPG: $error');
    }
  }

  Future<void> _importUrl() async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null) {
      setState(() => _message = 'URL XMLTV inválida');
      return;
    }
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final count = await _repository.importXmltvUrl(uri);
      await _load();
      if (mounted)
        setState(() => _message = 'EPG remoto guardado: $count programas');
    } catch (error) {
      if (mounted) setState(() => _message = 'Error: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _import() async {
    setState(() {
      _importing = true;
      _message = null;
    });
    try {
      final count = await _repository.importXmltv(_xml.text);
      await _load();
      if (mounted) setState(() => _message = 'EPG importado: $count programas');
    } catch (error) {
      if (mounted) setState(() => _message = 'Error: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _xml.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('EPG')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'URL XMLTV',
              hintText: 'https://servidor/epg.xml',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _importing ? null : _importUrl,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Cargar / actualizar desde URL'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _xml,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'XMLTV',
              hintText: '<tv>...</tv>',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _importing ? null : _import,
            icon: const Icon(Icons.download),
            label: const Text('Importar XMLTV'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_message!),
            ),
          const SizedBox(height: 20),
          Text(_programmes.isEmpty
              ? 'No hay EPG cargado.'
              : '${_programmes.length} programas almacenados.'),
          ..._programmes.take(30).map((programme) => ListTile(
                leading: const Icon(Icons.event),
                title: Text(programme.title),
                subtitle: Text(
                    '${programme.channelId} · ${programme.start.toLocal()}'),
              )),
        ],
      ),
    );
  }
}
