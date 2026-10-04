import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reproductor_iptv/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android device smoke test boots the IPTV home', (tester) async {
    app.main();

    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('TV en directo'), findsOneWidget);
    expect(find.textContaining('Demo IPTV'), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);
  });
}
