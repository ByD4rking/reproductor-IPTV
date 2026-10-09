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
    expect(find.text('Agregar primera playlist'), findsOneWidget);
    expect(find.text('Demo News'), findsNothing);
    expect(find.byTooltip('Ajustes'), findsOneWidget);
  });
}
