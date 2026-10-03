import 'package:flutter/material.dart';

void main() => runApp(const IptvApp());

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'reproductor-IPTV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: Center(child: Text('reproductor-IPTV')),
        ),
      );
}
