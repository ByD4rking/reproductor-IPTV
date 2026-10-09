import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reproductor_iptv/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android device smoke test boots the IPTV home', (tester) async {
    app.main();

    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Reproductor IPTV'), findsOneWidget);
    expect(find.text('Agregar primera playlist'), findsOneWidget);
    expect(find.text('Demo News'), findsNothing);
  });
}
