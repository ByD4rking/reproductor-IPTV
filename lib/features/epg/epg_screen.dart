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
  bool _loading = true;
  bool _importing = false;
  List<dynamic> _programmes = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await _repository.load();
    if (!mounted) return;
    setState(() {
      _programmes = values;
      _loading = false;
    });
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
    _xml.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('EPG')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          if (_message != null) Padding(
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
            subtitle: Text('${programme.channelId} · ${programme.start.toLocal()}'),
          )),
        ],
      ),
    );
  }
}
