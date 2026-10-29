import 'package:flutter_test/flutter_test.dart';
import 'package:app_casas/main.dart';

void main() {
  testWidgets('App Casas mostra tela inicial e busca', (tester) async {
    await tester.pumpWidget(const AppCasasApp());
    await tester.pumpAndSettle();
    expect(find.text('App Casas'), findsWidgets);
    expect(find.text('Encontre seu próximo lar'), findsOneWidget);
  });
}
