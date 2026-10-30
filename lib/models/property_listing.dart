import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

enum DealType { rent, buy }

extension DealTypeLabel on DealType {
  String get label => this == DealType.rent ? 'Alugar' : 'Comprar';
  String get firestoreValue => this == DealType.rent ? 'rent' : 'buy';

  static DealType fromValue(Object? value) =>
      value == 'rent' ? DealType.rent : DealType.buy;
}

enum PropertyCategory { apartment, studio, house, gatedHouse }

extension PropertyCategoryLabel on PropertyCategory {
  String get label => switch (this) {
        PropertyCategory.apartment => 'Apartamento',
        PropertyCategory.studio => 'Kitnet/Studio',
        PropertyCategory.house => 'Casa',
        PropertyCategory.gatedHouse => 'Casa em condomínio',
      };

  static PropertyCategory fromValue(Object? value) =>
      PropertyCategory.values.firstWhere(
        (item) => item.name == value,
        orElse: () => PropertyCategory.apartment,
      );
}

enum ListingStatus { active, paused, rented, sold, deleted }

class ListingPhoto {
  const ListingPhoto({required this.url, required this.storagePath});

  final String url;
  final String storagePath;

  factory ListingPhoto.fromMap(Map<String, dynamic> data) => ListingPhoto(
        url: data['url'] as String? ?? '',
        storagePath: data['storagePath'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'url': url, 'storagePath': storagePath};
}

class ListingPhotoSelection {
  const ListingPhotoSelection.existing(this.photo) : file = null;
  const ListingPhotoSelection.newFile(this.file) : photo = null;

  final ListingPhoto? photo;
  final XFile? file;
}

class ListingPrivateDetails {
  const ListingPrivateDetails({
    this.street = '',
    this.number = '',
    this.complement = '',
    this.postalCode = '',
    this.advertiserName = '',
  });

  final String street;
  final String number;
  final String complement;
  final String postalCode;
  final String advertiserName;

  factory ListingPrivateDetails.fromMap(Map<String, dynamic> data) =>
      ListingPrivateDetails(
        street: data['street'] as String? ?? '',
        number: data['number'] as String? ?? '',
        complement: data['complement'] as String? ?? '',
        postalCode: data['postalCode'] as String? ?? '',
        advertiserName: data['advertiserName'] as String? ?? '',
      );

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'street': street.trim(),
        'number': number.trim(),
        'complement': complement.trim(),
        'postalCode': postalCode.trim(),
        'advertiserName': advertiserName.trim(),
      };
}

class ListingContactDetails {
  const ListingContactDetails({required this.phone});

  final String phone;

  factory ListingContactDetails.fromMap(Map<String, dynamic> data) =>
      ListingContactDetails(phone: data['phone'] as String? ?? '');

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'phone': phone.trim(),
      };
}

class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.dealType,
    required this.category,
    required this.neighborhood,
    required this.city,
    required this.state,
    this.postalCodePrefix = '',
    required this.price,
    required this.description,
    required this.status,
    required this.photos,
    required this.phonePublished,
    this.whatsappAvailable = false,
    required this.fullAddressPublished,
    this.publicAddress = '',
    this.condoFee,
    this.propertyTax,
    this.area,
    this.bedrooms,
    this.bathrooms,
    this.parkingSpaces,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.isDemo = false,
  });

  final String id;
  final String ownerUid;
  final String title;
  final DealType dealType;
  final PropertyCategory category;
  final String neighborhood;
  final String city;
  final String state;
  final String postalCodePrefix;
  final double price;
  final double? condoFee;
  final double? propertyTax;
  final double? area;
  final int? bedrooms;
  final int? bathrooms;
  final int? parkingSpaces;
  final String description;
  final ListingStatus status;
  final List<ListingPhoto> photos;
  final bool phonePublished;
  final bool whatsappAvailable;
  final bool fullAddressPublished;
  final String publicAddress;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final bool isDemo;

  String get shortLocation => [neighborhood, city, state]
      .where((part) => part.trim().isNotEmpty)
      .join(', ');

  factory PropertyListing.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['createdAt'];
    final photos = (data['photos'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((photo) => ListingPhoto.fromMap(Map<String, dynamic>.from(photo)))
        .where((photo) => photo.url.isNotEmpty)
        .toList();

    return PropertyListing(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      dealType: DealTypeLabel.fromValue(data['dealType']),
      category: PropertyCategoryLabel.fromValue(data['category']),
      neighborhood: data['neighborhood'] as String? ?? '',
      city: data['city'] as String? ?? '',
      state: data['state'] as String? ?? '',
      postalCodePrefix: data['postalCodePrefix'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      condoFee: (data['condoFee'] as num?)?.toDouble(),
      propertyTax: (data['propertyTax'] as num?)?.toDouble(),
      area: (data['area'] as num?)?.toDouble(),
      bedrooms: (data['bedrooms'] as num?)?.toInt(),
      bathrooms: (data['bathrooms'] as num?)?.toInt(),
      parkingSpaces: (data['parkingSpaces'] as num?)?.toInt(),
      description: data['description'] as String? ?? '',
      status: ListingStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => ListingStatus.active,
      ),
      photos: photos,
      phonePublished: data['phonePublished'] as bool? ?? false,
      // Older listings showed WhatsApp whenever a public phone was available.
      whatsappAvailable: data['whatsappAvailable'] as bool? ?? true,
      fullAddressPublished: data['fullAddressPublished'] as bool? ?? false,
      publicAddress: data['publicAddress'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  Map<String, dynamic> toPublicMap({required String ownerUid}) => {
        'ownerUid': ownerUid,
        'title': title.trim(),
        'dealType': dealType.firestoreValue,
        'category': category.name,
        'neighborhood': neighborhood.trim(),
        'city': city.trim(),
        'state': state.trim().toUpperCase(),
        if (postalCodePrefix.isNotEmpty) 'postalCodePrefix': postalCodePrefix,
        'price': price,
        if (condoFee != null) 'condoFee': condoFee,
        if (propertyTax != null) 'propertyTax': propertyTax,
        if (area != null) 'area': area,
        if (bedrooms != null) 'bedrooms': bedrooms,
        if (bathrooms != null) 'bathrooms': bathrooms,
        if (parkingSpaces != null) 'parkingSpaces': parkingSpaces,
        'description': description.trim(),
        'status': status.name,
        'photos': photos.map((photo) => photo.toMap()).toList(),
        'phonePublished': phonePublished,
        'whatsappAvailable': whatsappAvailable,
        'fullAddressPublished': fullAddressPublished,
        if (fullAddressPublished && publicAddress.trim().isNotEmpty)
          'publicAddress': publicAddress.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  PropertyListing copyWith({
    String? id,
    String? ownerUid,
    String? title,
    DealType? dealType,
    PropertyCategory? category,
    String? neighborhood,
    String? city,
    String? state,
    String? postalCodePrefix,
    double? price,
    double? condoFee,
    double? propertyTax,
    double? area,
    int? bedrooms,
    int? bathrooms,
    int? parkingSpaces,
    String? description,
    ListingStatus? status,
    List<ListingPhoto>? photos,
    bool? phonePublished,
    bool? whatsappAvailable,
    bool? fullAddressPublished,
    String? publicAddress,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) =>
      PropertyListing(
        id: id ?? this.id,
        ownerUid: ownerUid ?? this.ownerUid,
        title: title ?? this.title,
        dealType: dealType ?? this.dealType,
        category: category ?? this.category,
        neighborhood: neighborhood ?? this.neighborhood,
        city: city ?? this.city,
        state: state ?? this.state,
        postalCodePrefix: postalCodePrefix ?? this.postalCodePrefix,
        price: price ?? this.price,
        condoFee: condoFee ?? this.condoFee,
        propertyTax: propertyTax ?? this.propertyTax,
        area: area ?? this.area,
        bedrooms: bedrooms ?? this.bedrooms,
        bathrooms: bathrooms ?? this.bathrooms,
        parkingSpaces: parkingSpaces ?? this.parkingSpaces,
        description: description ?? this.description,
        status: status ?? this.status,
        photos: photos ?? this.photos,
        phonePublished: phonePublished ?? this.phonePublished,
        whatsappAvailable: whatsappAvailable ?? this.whatsappAvailable,
        fullAddressPublished:
            fullAddressPublished ?? this.fullAddressPublished,
        publicAddress: publicAddress ?? this.publicAddress,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        createdAt: createdAt ?? this.createdAt,
        isDemo: isDemo,
      );
}

class ListingDraft {
  const ListingDraft({
    required this.listing,
    required this.privateDetails,
    required this.contactDetails,
  });

  final PropertyListing listing;
  final ListingPrivateDetails privateDetails;
  final ListingContactDetails contactDetails;
}
