import 'package:app_casas/models/property_listing.dart';
import 'package:app_casas/services/listing_filters.dart';
import 'package:flutter_test/flutter_test.dart';

PropertyListing _listing({
  bool whatsappAvailable = false,
  bool fullAddressPublished = false,
  String publicAddress = '',
}) =>
    PropertyListing(
      id: 'abc123',
      ownerUid: 'owner-1',
      title: 'Apartamento bem iluminado',
      dealType: DealType.rent,
      category: PropertyCategory.apartment,
      neighborhood: 'Centro',
      city: 'Cuiabá',
      state: 'MT',
      price: 1800,
      description: 'Espaço confortável perto de serviços.',
      status: ListingStatus.active,
      photos: const [],
      phonePublished: true,
      whatsappAvailable: whatsappAvailable,
      fullAddressPublished: fullAddressPublished,
      publicAddress: publicAddress,
    );

void main() {
  group('dados públicos e privados do anúncio', () {
    test('telefone e endereço exato não entram na listagem pública por padrão', () {
      final public = _listing().toPublicMap(ownerUid: 'owner-1');

      expect(public['phonePublished'], isTrue);
      expect(public['whatsappAvailable'], isFalse);
      expect(public.containsKey('phone'), isFalse);
      expect(public.containsKey('publicAddress'), isFalse);
    });

    test('endereço completo só é publicado quando a pessoa escolhe divulgar', () {
      final public = _listing(
        fullAddressPublished: true,
        publicAddress: 'Rua das Flores, 20, Centro, Cuiabá - MT',
      ).toPublicMap(ownerUid: 'owner-1');

      expect(public['publicAddress'], 'Rua das Flores, 20, Centro, Cuiabá - MT');
    });

    test('contato e endereço privado ficam em documentos separados', () {
      final private = const ListingPrivateDetails(
        street: 'Rua das Flores',
        number: '20',
        postalCode: '78000-000',
        advertiserName: 'Ana',
      ).toMap('owner-1');
      final contact =
          const ListingContactDetails(phone: '(65) 99999-9999').toMap('owner-1');

      expect(private['ownerUid'], 'owner-1');
      expect(private['street'], 'Rua das Flores');
      expect(private.containsKey('phone'), isFalse);
      expect(contact['phone'], '(65) 99999-9999');
    });

    test('WhatsApp só fica disponível quando o anunciante habilita a opção', () {
      final public = _listing(whatsappAvailable: true)
          .toPublicMap(ownerUid: 'owner-1');

      expect(public['phonePublished'], isTrue);
      expect(public['whatsappAvailable'], isTrue);
      expect(public.containsKey('phone'), isFalse);
    });

    test('anúncios antigos preservam o botão de WhatsApp', () {
      final legacy = PropertyListing.fromMap('old-listing', {
        'phonePublished': true,
      });

      expect(legacy.whatsappAvailable, isTrue);
      expect(legacy.copyWith(price: 2000).whatsappAvailable, isTrue);
    });
  });

  test('categorias e tipo de negociação têm rótulos em português', () {
    expect(DealType.rent.label, 'Alugar');
    expect(DealType.buy.label, 'Comprar');
    expect(PropertyCategory.studio.label, 'Kitnet/Studio');
    expect(PropertyCategory.gatedHouse.label, 'Casa em condomínio');
  });

  group('filtros de localização', () {
    test('busca endereço completo somente quando ele foi divulgado', () {
      final privateAddress = _listing(
        publicAddress: 'Rua das Flores, 20',
      );
      final publicAddress = _listing(
        fullAddressPublished: true,
        publicAddress: 'Rua das Flores, 20',
      );

      expect(matchesListingSearch(privateAddress, 'Rua das Flores'), isFalse);
      expect(matchesListingSearch(publicAddress, 'Rua das Flores'), isTrue);
    });

    test('busca por localização não inclui imóveis sem coordenadas ou distantes', () {
      const latitude = -15.601;
      const longitude = -56.097;
      final nearby = _listing().copyWith(
        latitude: -15.6,
        longitude: -56.1,
      );
      final distant = _listing().copyWith(
        latitude: -14.0,
        longitude: -56.0,
      );

      expect(
        listingIsWithinRadius(
          _listing(),
          latitude: latitude,
          longitude: longitude,
        ),
        isFalse,
      );
      expect(
        listingIsWithinRadius(
          nearby,
          latitude: latitude,
          longitude: longitude,
        ),
        isTrue,
      );
      expect(
        listingIsWithinRadius(
          distant,
          latitude: latitude,
          longitude: longitude,
        ),
        isFalse,
      );
    });
  });
}
