import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ajustes')),
    body: ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.autorenew),
          title: Text('Recuperación automática'),
          subtitle: Text('Detectar congelamientos y recuperar la reproducción.'),
          trailing: Switch(value: true, onChanged: null),
        ),
        ListTile(
          leading: Icon(Icons.swap_horiz),
          title: Text('Cambio automático de fuente'),
          subtitle: Text('Permitido solo entre fuentes del mismo canal.'),
          trailing: Switch(value: true, onChanged: null),
        ),
        ListTile(
          leading: Icon(Icons.network_check),
          title: Text('Diagnóstico'),
          subtitle: Text('Red, buffer, estado del stream y fuente activa.'),
        ),
      ],
    ),
  );
}
