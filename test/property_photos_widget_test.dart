import 'package:app_casas/models/property_listing.dart';
import 'package:app_casas/property_card.dart';
import 'package:app_casas/property_detail_page.dart';
import 'package:app_casas/services/listing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cartões mostram ícone neutro sem foto e imagem quando há foto',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 470,
            child: Row(children: [
              Expanded(
                child: PropertyCard(
                  listing: _listing(),
                  saved: false,
                  onTap: () {},
                  onFavorite: () {},
                  showFavorite: false,
                ),
              ),
              Expanded(
                child: PropertyCard(
                  listing: _listing(photos: const [
                    ListingPhoto(
                      url: 'https://example.test/imovel.jpg',
                      storagePath: '',
                    ),
                  ]),
                  saved: false,
                  onTap: () {},
                  onFavorite: () {},
                  showFavorite: false,
                ),
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(PropertyCard), findsNWidgets(2));
    expect(find.byIcon(Icons.home_work_rounded), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('detalhes de anúncio sem fotos usam espaço reservado neutro',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PropertyDetailPage(
        listing: _listing(),
        firebaseReady: false,
        repository: const ListingRepository(firebaseReady: false),
        onLoginRequired: () async {},
      ),
    ));
    await tester.pump();

    expect(find.text('Detalhes do imóvel'), findsOneWidget);
    expect(find.byIcon(Icons.home_work_rounded), findsOneWidget);
    expect(find.text('Exemplo'), findsNothing);
  });
}

PropertyListing _listing({List<ListingPhoto> photos = const []}) =>
    PropertyListing(
      id: 'imovel-1',
      ownerUid: 'owner-1',
      title: 'Apartamento para teste',
      dealType: DealType.rent,
      category: PropertyCategory.apartment,
      neighborhood: 'Centro',
      city: 'Cuiabá',
      state: 'MT',
      price: 1800,
      description: 'Imóvel amplo, iluminado e perto de serviços.',
      status: ListingStatus.active,
      photos: photos,
      phonePublished: false,
      fullAddressPublished: false,
    );
