import 'package:app_casas/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visitante pode pesquisar no modo demonstração', (tester) async {
    await tester.pumpWidget(const AppCasasApp(
      firebaseReady: false,
      googleAuthReady: false,
    ));
    await tester.pumpAndSettle();

    expect(find.text('App Casas'), findsOneWidget);
    expect(find.text('Alugar um imóvel'), findsOneWidget);
    expect(find.text('Comprar um imóvel'), findsOneWidget);
    expect(find.text('Anunciar um imóvel'), findsOneWidget);
    expect(find.textContaining('Modo demonstração'), findsOneWidget);
    expect(find.text('Buscar imóveis'), findsOneWidget);
    expect(find.textContaining('3 imóveis encontrados'), findsOneWidget);
  });

  testWidgets('detalhes do imóvel de exemplo abrem sem login', (tester) async {
    await tester.pumpWidget(const AppCasasApp(
      firebaseReady: false,
      googleAuthReady: false,
    ));
    await tester.pumpAndSettle();

    final listingTitle = find.text('Apartamento claro perto do parque');
    await tester.ensureVisible(listingTitle);
    await tester.tap(listingTitle);
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do imóvel'), findsOneWidget);
    expect(find.text('Sobre o imóvel'), findsOneWidget);
  });
}
