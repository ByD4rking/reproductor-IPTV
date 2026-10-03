import 'package:flutter/material.dart';

class EpgScreen extends StatelessWidget {
  const EpgScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EPG')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ListTile(
          leading: Icon(Icons.circle, color: Colors.red),
          title: Text('Ahora'),
          subtitle: Text('EPG listo para conectarse al XMLTV de la playlist.'),
        ),
        ListTile(
          leading: Icon(Icons.schedule),
          title: Text('Siguiente'),
          subtitle: Text('La guía se mantendrá independiente de la reproducción.'),
        ),
      ],
    ),
  );
}
