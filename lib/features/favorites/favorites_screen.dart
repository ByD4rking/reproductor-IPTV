import 'package:flutter/material.dart';
import '../../core/favorites/favorite_repository.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = FavoriteRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder(
        future: repository.load(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final favorites = snapshot.data!;
          if (favorites.isEmpty) {
            return const Center(
                child: Text('No hay canales favoritos todavía.'));
          }
          return ListView.builder(
            itemCount: favorites.length,
            itemBuilder: (_, index) => ListTile(
              leading: const Icon(Icons.star),
              title: Text(favorites[index].channelId),
              subtitle: Text(
                  favorites[index].preferredSourceId ?? 'Fuente automática'),
            ),
          );
        },
      ),
    );
  }
}
