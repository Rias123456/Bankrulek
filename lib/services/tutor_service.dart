import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/tutor.dart';

class TutorService {
  TutorService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String tutorsCollection = 'tutors';
  static const String _photoFolder = 'tutor_photos';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(tutorsCollection);

  Future<List<Tutor>> fetchTutors() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection.get();
    return snapshot.docs.map(Tutor.fromFirestore).toList();
  }

  Future<Tutor?> fetchTutorById(String tutorId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _collection.doc(tutorId).get();
    if (!snapshot.exists) {
      return null;
    }
    return Tutor.fromFirestore(snapshot);
  }

  Future<Tutor?> fetchTutorByEmailAndPassword(
    String email,
    String password,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .where('email', isEqualTo: email.trim())
        .where('password', isEqualTo: password.trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return Tutor.fromFirestore(snapshot.docs.first);
  }

  Future<Tutor> addTutor({
    required String fullName,
    required String nickname,
    required String phoneNumber,
    required String lineId,
    required String email,
    required String password,
    String currentActivity = '',
    String status = Tutor.defaultStatus,
    String travelTime = Tutor.defaultTravelDuration,
    List<String> subjects = const <String>[],
    List<TutorScheduleEntry> schedule = const <TutorScheduleEntry>[],
    Uint8List? photoBytes,
    String? photoBase64,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _collection.doc();
    String resolvedFirstName = '';
    String resolvedLastName = '';
    final String trimmedFullName = fullName.trim();
    if (trimmedFullName.isNotEmpty) {
      final List<String> parts = trimmedFullName
          .split(RegExp(r'\s+'))
          .where((String part) => part.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        resolvedFirstName = parts.first;
        resolvedLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }
    String? photoUrl;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoUrl = await uploadTutorPhoto(ref.id, photoBytes);
    }
    final Tutor tutor = Tutor(
      id: ref.id,
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      currentActivity: currentActivity,
      nickname: nickname,
      phoneNumber: phoneNumber,
      lineId: lineId,
      email: email,
      password: password,
      status: status,
      travelDuration: travelTime,
      profileImageBase64: photoBase64,
      photoUrl: photoUrl,
      subjects: subjects,
      teachingSchedule: null,
      schedule: schedule,
    );
    final Map<String, dynamic> data = tutor.toFirestoreMap(includeTimestamps: true)
      ..putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
    await ref.set(data);
    final DocumentSnapshot<Map<String, dynamic>> freshSnapshot = await ref.get();
    return Tutor.fromFirestore(freshSnapshot);
  }

  Future<Tutor> updateTutor(
    Tutor tutor, {
    Uint8List? photoBytes,
    String? photoBase64,
  }) async {
    String? photoUrl = tutor.photoUrl;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      photoUrl = await uploadTutorPhoto(tutor.id, photoBytes);
    }
    final Tutor updated = tutor.copyWith(
      photoUrl: photoUrl,
      profileImageBase64: photoBase64 ?? tutor.profileImageBase64,
    );
    final Map<String, dynamic> data = updated.toFirestoreMap(includeTimestamps: true);
    if (updated.profileImageBase64 == null || updated.profileImageBase64!.isEmpty) {
      data['photoBase64'] = FieldValue.delete();
    }
    if (updated.photoUrl == null || updated.photoUrl!.isEmpty) {
      data['photoUrl'] = FieldValue.delete();
    }
    if (updated.teachingSchedule == null || updated.teachingSchedule!.isEmpty) {
      data['scheduleSerialized'] = FieldValue.delete();
    }
    await _collection.doc(tutor.id).update(data);
    final DocumentSnapshot<Map<String, dynamic>> freshSnapshot =
        await _collection.doc(tutor.id).get();
    return Tutor.fromFirestore(freshSnapshot);
  }

  Future<void> deleteTutor(String tutorId) async {
    await _collection.doc(tutorId).delete();
  }

  Future<String> uploadTutorPhoto(String tutorId, Uint8List data) async {
    final Reference ref =
        _storage.ref().child(_photoFolder).child('$tutorId-${DateTime.now().millisecondsSinceEpoch}.jpg');
    final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
    final UploadTask task = ref.putData(data, metadata);
    final TaskSnapshot snapshot = await task.whenComplete(() => null);
    return snapshot.ref.getDownloadURL();
  }
}
