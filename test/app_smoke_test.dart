import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/app/app.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('app renders IPTV home shell', (tester) async {
    await tester.pumpWidget(const ReproductorIptvApp());
    await tester.pumpAndSettle();
    expect(find.text('Reproductor IPTV'), findsWidgets);
    expect(find.text('TV en directo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Demo News'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Demo News'), findsOneWidget);
    expect(find.byTooltip('Ajustes'), findsOneWidget);
    expect(find.byTooltip('Playlists'), findsOneWidget);
  });
}
