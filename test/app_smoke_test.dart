import 'package:flutter_test/flutter_test.dart';
import 'package:reproductor_iptv/app/app.dart';

void main() {
  testWidgets('app renders IPTV home shell', (tester) async {
    await tester.pumpWidget(const ReproductorIptvApp());
    expect(find.text('Reproductor IPTV'), findsWidgets);
    expect(find.text('TV en directo'), findsOneWidget);
    expect(find.text('Demo News'), findsOneWidget);
  });
}
