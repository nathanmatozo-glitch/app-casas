import 'package:app_casas/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App Casas apresenta o ambiente de login Google', (tester) async {
    await tester.pumpWidget(const AppCasasApp(firebaseReady: false));
    await tester.pumpAndSettle();

    expect(find.text('App Casas'), findsOneWidget);
    expect(find.text('Continuar com Google'), findsOneWidget);
    expect(find.textContaining('Configuração necessária'), findsOneWidget);
  });
}
