import 'package:flutter/material.dart';
import '../../core/history/history_repository.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = HistoryRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: FutureBuilder(
        future: repository.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final history = snapshot.data!;
          if (history.isEmpty) {
            return const Center(
                child: Text('Todavía no hay sesiones de reproducción.'));
          }
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (_, index) {
              final item = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(item.channelId),
                subtitle: Text(item.startedAt.toLocal().toString()),
                trailing: Text('${item.duration.inSeconds} s'),
              );
            },
          );
        },
      ),
    );
  }
}
