import 'package:app_casas/listing_form_page.dart';
import 'package:app_casas/models/property_listing.dart';
import 'package:app_casas/services/listing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('publica um anúncio sem fotos', (tester) async {
    final repository = _CapturingListingRepository();
    await _pumpForm(tester, repository);
    await _completeNewListing(tester);

    expect(
      find.text(
        'Adicionar fotos é recomendado para valorizar seu imóvel, mas você pode publicar o anúncio sem imagens durante esta fase de testes.',
      ),
      findsOneWidget,
    );
    final publishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publicar anúncio'),
    );
    expect(publishButton.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar anúncio'));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.savedPhotos, isEmpty);
    expect(repository.savedDraft!.listing.photos, isEmpty);
  });

  testWidgets('publica com uma foto selecionada', (tester) async {
    final repository = _CapturingListingRepository();
    await _pumpForm(
      tester,
      repository,
      photoPicker: () async => [XFile('/tmp/foto-unica.jpg')],
    );
    await _completeNewListing(tester);
    await _addPhotos(tester);

    expect(find.text('Foto 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar anúncio'));
    await tester.pumpAndSettle();

    expect(repository.savedPhotos, hasLength(1));
    expect(repository.savedPhotos.single.file!.name, 'foto-unica.jpg');
  });

  testWidgets('publica com várias fotos selecionadas', (tester) async {
    final repository = _CapturingListingRepository();
    await _pumpForm(
      tester,
      repository,
      photoPicker: () async => [
        XFile('/tmp/foto-1.jpg'),
        XFile('/tmp/foto-2.jpg'),
        XFile('/tmp/foto-3.jpg'),
      ],
    );
    await _completeNewListing(tester);
    await _addPhotos(tester);

    expect(find.text('Foto 1'), findsOneWidget);
    expect(find.text('Foto 2'), findsOneWidget);
    expect(find.text('Foto 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publicar anúncio'));
    await tester.pumpAndSettle();

    expect(repository.savedPhotos, hasLength(3));
  });

  testWidgets('abre e salva a edição de um anúncio sem fotos', (tester) async {
    final listing = _validListing(id: 'anuncio-existente');
    final repository = _CapturingListingRepository(
      editDraft: ListingDraft(
        listing: listing,
        privateDetails: const ListingPrivateDetails(
          street: 'Rua das Flores',
          number: '20',
          postalCode: '78000-000',
          advertiserName: 'Ana Teste',
        ),
        contactDetails:
            const ListingContactDetails(phone: '(65) 99999-9999'),
      ),
    );
    await _pumpForm(tester, repository, listing: listing);

    await _tapContinue(tester);
    await _tapContinue(tester);
    await _tapContinue(tester);
    expect(find.text('Adicionar fotos'), findsOneWidget);
    expect(find.text('Foto 1'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();

    expect(repository.saveCount, 1);
    expect(repository.savedDraft!.listing.id, 'anuncio-existente');
    expect(repository.savedPhotos, isEmpty);
  });

  testWidgets('mantém a validação obrigatória do título', (tester) async {
    final repository = _CapturingListingRepository();
    await _pumpForm(tester, repository);

    await _tapContinue(tester);

    expect(find.text('Etapa 1 de 4'), findsOneWidget);
    expect(find.text('Escreva um título.'), findsOneWidget);
    expect(repository.saveCount, 0);
  });
}

Future<void> _pumpForm(
  WidgetTester tester,
  _CapturingListingRepository repository, {
  Future<List<XFile>> Function()? photoPicker,
  PropertyListing? listing,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: ListingFormPage(
      uid: 'owner-1',
      firebaseReady: true,
      repository: repository,
      listing: listing,
      photoPicker: photoPicker,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _completeNewListing(WidgetTester tester) async {
  await _enterField(tester, 'Dê um título ao anúncio', 'Apartamento para teste');
  await _tapContinue(tester);

  await _enterField(tester, 'Rua ou avenida', 'Rua das Flores');
  await _enterField(tester, 'Número', '20');
  await _enterField(tester, 'Bairro', 'Centro');
  await _enterField(tester, 'Cidade', 'Cuiabá');
  await _enterField(tester, 'Estado', 'MT');
  await _enterField(tester, 'CEP', '78000-000');
  await _tapContinue(tester);

  await _enterField(tester, 'Valor do aluguel', '1800');
  await _enterField(
    tester,
    'Conte um pouco sobre o imóvel',
    'Imóvel amplo, iluminado e perto de serviços.',
  );
  await _tapContinue(tester);
}

Future<void> _addPhotos(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(OutlinedButton, 'Adicionar fotos'));
  await tester.pumpAndSettle();
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
  await tester.pumpAndSettle();
}

Future<void> _enterField(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byWidgetPredicate(
    (widget) =>
        widget is TextFormField && widget.decoration.labelText == label,
  );
  expect(field, findsOneWidget, reason: 'Campo "$label" deve estar disponível.');
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

PropertyListing _validListing({required String id}) => PropertyListing(
      id: id,
      ownerUid: 'owner-1',
      title: 'Apartamento para teste',
      dealType: DealType.rent,
      category: PropertyCategory.apartment,
      neighborhood: 'Centro',
      city: 'Cuiabá',
      state: 'MT',
      postalCodePrefix: '78000',
      price: 1800,
      description: 'Imóvel amplo, iluminado e perto de serviços.',
      status: ListingStatus.active,
      photos: const [],
      phonePublished: true,
      fullAddressPublished: false,
    );

class _CapturingListingRepository extends ListingRepository {
  _CapturingListingRepository({this.editDraft}) : super(firebaseReady: true);

  final ListingDraft? editDraft;
  int saveCount = 0;
  ListingDraft? savedDraft;
  List<ListingPhotoSelection> savedPhotos = const [];

  @override
  Future<Map<String, String>> getContactDefaults(String uid) async => {
        'advertiserName': 'Ana Teste',
        'phone': '(65) 99999-9999',
      };

  @override
  Future<ListingDraft> getOwnerDraft(String propertyId) async => editDraft!;

  @override
  Future<String> saveListing({
    required String uid,
    required ListingDraft draft,
    required List<ListingPhotoSelection> photoSelections,
  }) async {
    saveCount++;
    savedDraft = draft;
    savedPhotos = List.unmodifiable(photoSelections);
    return draft.listing.id.isEmpty ? 'anuncio-novo' : draft.listing.id;
  }
}
