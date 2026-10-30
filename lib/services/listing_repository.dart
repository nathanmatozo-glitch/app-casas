import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../data/demo_listings.dart';
import '../firebase_options.dart';
import '../models/property_listing.dart';

class ListingRepository {
  const ListingRepository({required this.firebaseReady});

  final bool firebaseReady;

  CollectionReference<Map<String, dynamic>> get _properties =>
      FirebaseFirestore.instance.collection('properties');

  Stream<List<PropertyListing>> watchActiveListings() {
    if (!firebaseReady) return Stream.value(demoListings);
    return _properties
        .where('status', isEqualTo: ListingStatus.active.name)
        .snapshots()
        .map((snapshot) {
          final result = snapshot.docs
              .map((doc) => PropertyListing.fromMap(doc.id, doc.data()))
              .toList();
          result.sort((a, b) =>
              (b.createdAt ?? DateTime(2000)).compareTo(
                a.createdAt ?? DateTime(2000),
              ));
          return result;
        });
  }

  Stream<List<PropertyListing>> watchOwnerListings(String uid) => _properties
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PropertyListing.fromMap(doc.id, doc.data()))
          .toList());

  Stream<Set<String>> watchFavoriteIds(String uid) => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('favorites')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());

  Future<Map<String, String>> getContactDefaults(String uid) async {
    final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return {
      'advertiserName': user.data()?['advertiserName'] as String? ?? '',
      'phone': user.data()?['phone'] as String? ?? '',
    };
  }

  Future<void> setFavorite({
    required String uid,
    required String propertyId,
    required bool saved,
  }) async {
    final reference = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId);
    if (saved) {
      await reference.set({'propertyId': propertyId});
    } else {
      await reference.delete();
    }
  }

  Future<ListingDraft> getOwnerDraft(String propertyId) async {
    final property = await _properties.doc(propertyId).get();
    final privateRef = FirebaseFirestore.instance
        .collection('propertyPrivate')
        .doc(propertyId);
    final contactRef = FirebaseFirestore.instance
        .collection('propertyContacts')
        .doc(propertyId);
    final privateAndContact = await Future.wait([
      privateRef.get(),
      contactRef.get(),
    ]);
    final private = privateAndContact[0];
    final contact = privateAndContact[1];
    if (!property.exists || !private.exists) {
      throw StateError('Este anúncio não está mais disponível para edição.');
    }
    return ListingDraft(
      listing: PropertyListing.fromMap(property.id, property.data()!),
      privateDetails: ListingPrivateDetails.fromMap(private.data()!),
      contactDetails: ListingContactDetails.fromMap(
        contact.data() ?? const <String, dynamic>{},
      ),
    );
  }

  Future<String> saveListing({
    required String uid,
    required ListingDraft draft,
    required List<ListingPhotoSelection> photoSelections,
  }) async {
    if (!firebaseReady) {
      throw StateError('Conecte o Firebase para publicar e salvar anúncios.');
    }
    if (DefaultFirebaseOptions.storageBucket.isEmpty) {
      throw StateError(
        'O armazenamento de fotos ainda não está configurado no Firebase.',
      );
    }
    if (photoSelections.isEmpty) {
      throw StateError('Adicione pelo menos uma foto do imóvel.');
    }

    final document = draft.listing.id.isEmpty
        ? _properties.doc()
        : _properties.doc(draft.listing.id);
    final uploadedPaths = <String>[];
    final photos = <ListingPhoto>[];

    try {
      for (var index = 0; index < photoSelections.length; index++) {
        final selection = photoSelections[index];
        if (selection.photo != null) {
          photos.add(selection.photo!);
          continue;
        }
        final file = selection.file;
        if (file == null) continue;
        final extension = _extension(file.name);
        final path = 'properties/$uid/${document.id}/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
        final reference = FirebaseStorage.instance.ref(path);
        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          throw StateError('Cada foto precisa ter até 10 MB.');
        }
        await reference.putData(
          bytes,
          SettableMetadata(contentType: _contentType(extension)),
        );
        uploadedPaths.add(path);
        photos.add(ListingPhoto(
          url: await reference.getDownloadURL(),
          storagePath: path,
        ));
      }

      final listing = draft.listing.copyWith(
        id: document.id,
        ownerUid: uid,
        photos: photos,
      );
      final batch = FirebaseFirestore.instance.batch();
      batch.set(document, listing.toPublicMap(ownerUid: uid));
      batch.set(
        FirebaseFirestore.instance
            .collection('propertyPrivate')
            .doc(document.id),
        draft.privateDetails.toMap(uid),
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('propertyContacts')
            .doc(document.id),
        draft.contactDetails.toMap(uid),
      );
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(uid),
        {
          'advertiserName': draft.privateDetails.advertiserName.trim(),
          'phone': draft.contactDetails.phone.trim(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      if (draft.listing.id.isNotEmpty) {
        final keptPaths = photos.map((photo) => photo.storagePath).toSet();
        for (final oldPhoto in draft.listing.photos) {
          if (oldPhoto.storagePath.isEmpty || keptPaths.contains(oldPhoto.storagePath)) {
            continue;
          }
          try {
            await FirebaseStorage.instance.ref(oldPhoto.storagePath).delete();
          } catch (error) {
            debugPrint('Não foi possível remover uma foto antiga: $error');
          }
        }
      }
      return document.id;
    } catch (_) {
      for (final path in uploadedPaths) {
        try {
          await FirebaseStorage.instance.ref(path).delete();
        } catch (error) {
          debugPrint('Não foi possível remover foto temporária: $error');
        }
      }
      rethrow;
    }
  }

  Future<void> updateStatus(String propertyId, ListingStatus status) async {
    await _properties.doc(propertyId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteListing(PropertyListing listing) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_properties.doc(listing.id));
    batch.delete(FirebaseFirestore.instance
        .collection('propertyPrivate')
        .doc(listing.id));
    batch.delete(FirebaseFirestore.instance
        .collection('propertyContacts')
        .doc(listing.id));
    await batch.commit();
    for (final photo in listing.photos) {
      if (photo.storagePath.isEmpty) continue;
      try {
        await FirebaseStorage.instance.ref(photo.storagePath).delete();
      } catch (error) {
        debugPrint('Não foi possível remover uma foto do anúncio: $error');
      }
    }
  }

  Future<String> phoneForContact(PropertyListing listing) async {
    if (!listing.phonePublished) {
      throw StateError('O anunciante escolheu não divulgar o telefone.');
    }
    final contact = await FirebaseFirestore.instance
        .collection('propertyContacts')
        .doc(listing.id)
        .get();
    final phone = contact.data()?['phone'] as String? ?? '';
    if (phone.trim().isEmpty) {
      throw StateError('O anunciante ainda não informou um telefone.');
    }
    return phone;
  }

  Future<void> reportListing({
    required String propertyId,
    required String reporterUid,
    required String reason,
  }) async {
    await FirebaseFirestore.instance.collection('reports').add({
      'propertyId': propertyId,
      'reporterUid': reporterUid,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  String _extension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2) return 'jpg';
    return parts.last.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  }

  String _contentType(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
}
