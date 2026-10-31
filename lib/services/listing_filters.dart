import 'package:geolocator/geolocator.dart';

import '../models/property_listing.dart';

bool matchesListingSearch(PropertyListing listing, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return true;

  final searchable = [
    listing.title,
    listing.neighborhood,
    listing.city,
    listing.state,
    listing.category.label,
    listing.postalCodePrefix,
    if (listing.fullAddressPublished) listing.publicAddress,
  ].join(' ').toLowerCase();
  final queryDigits = normalized.replaceAll(RegExp(r'\D'), '');

  return searchable.contains(normalized) ||
      (queryDigits.length >= 5 &&
          listing.postalCodePrefix.startsWith(queryDigits.substring(0, 5)));
}

bool listingIsWithinRadius(
  PropertyListing listing, {
  required double latitude,
  required double longitude,
  double radiusInMeters = 30000,
}) {
  final listingLatitude = listing.latitude;
  final listingLongitude = listing.longitude;
  if (listingLatitude == null || listingLongitude == null) return false;

  return Geolocator.distanceBetween(
        latitude,
        longitude,
        listingLatitude,
        listingLongitude,
      ) <=
      radiusInMeters;
}
