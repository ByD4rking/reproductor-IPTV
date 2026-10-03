import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';

class ReproductorIptvApp extends StatelessWidget {
  const ReproductorIptvApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Reproductor IPTV',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.cyan,
      scaffoldBackgroundColor: const Color(0xFF080B10),
    ),
    home: const HomeScreen(),
  );
}
