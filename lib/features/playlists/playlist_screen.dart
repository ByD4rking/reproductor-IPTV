import 'package:flutter/material.dart';
import '../../core/domain/entities/playlist.dart';

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({required this.playlist, super.key});
  final Playlist playlist;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Playlist')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.playlist_play)),
            title: Text(playlist.name),
            subtitle: Text('${playlist.entries.length} canales'),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Fuentes y canales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...playlist.entries.map((entry) => ListTile(
          leading: const Icon(Icons.live_tv),
          title: Text(entry.channel.displayName),
          subtitle: Text('${entry.category ?? 'Sin categoría'} · ${entry.sources.length} fuente(s)'),
        )),
      ],
    ),
  );
}
