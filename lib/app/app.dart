import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';

class ReproductorIptvApp extends StatelessWidget {
  const ReproductorIptvApp({super.key});

  static const _background = Color(0xFF080D14);
  static const _surface = Color(0xFF111A25);
  static const _accent = Color(0xFF36D6C5);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: Brightness.dark,
      surface: _surface,
    );

    return MaterialApp(
      title: 'Reproductor IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: scheme,
        scaffoldBackgroundColor: _background,
        canvasColor: _surface,
        visualDensity: VisualDensity.standard,
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: Color(0xFFF3F7FB),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          color: _surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.42)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0C131D),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.65)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _accent, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.error),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
          space: 1,
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF202B38),
          contentTextStyle: TextStyle(color: scheme.onSurface),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _accent,
          linearTrackColor: Color(0xFF263543),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: const Color(0xFFE5EDF5),
          displayColor: const Color(0xFFF3F7FB),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
