import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class TutorUpdateResult {
  const TutorUpdateResult({
    this.photoUrl,
  });

  final String? photoUrl;
}

class TutorService {
  TutorService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _tutorCollection =>
      _firestore.collection('tutors');

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final UserCredential credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final User? user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'ไม่พบบัญชีผู้ใช้',
      );
    }
    return user.uid;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<Map<String, dynamic>?> getTutor(String tutorId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _tutorCollection.doc(tutorId).get();
    return snapshot.data();
  }

  Future<void> addTutor({
    required String tutorId,
    required String fullName,
    required String nickname,
    required String phone,
    required String lineId,
    required String email,
    required String password,
    required String currentStatus,
    required String travelTime,
    required List<String> subjects,
    Uint8List? profileImageBytes,
  }) async {
    String? photoUrl;
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      photoUrl = await _uploadTutorImage(
        tutorId: tutorId,
        data: profileImageBytes,
      );
    }

    final List<String> normalizedSubjects =
        _normalizeSubjects(List<dynamic>.from(subjects));

    await _tutorCollection.doc(tutorId).set(<String, dynamic>{
      'fullName': fullName,
      'nickname': nickname,
      'phone': phone,
      'lineId': lineId,
      'email': email,
      'password': password,
      'photoUrl': photoUrl,
      'currentStatus': currentStatus,
      'travelTime': travelTime,
      'subjects': normalizedSubjects,
      'schedule': <Map<String, dynamic>>[],
    });
  }

  Future<TutorUpdateResult> updateTutor({
    required String tutorId,
    required Map<String, dynamic> data,
    Uint8List? newProfileImageBytes,
    bool removePhoto = false,
  }) async {
    final Map<String, dynamic> updates = Map<String, dynamic>.from(data);

    if (updates.containsKey('subjects')) {
      updates['subjects'] = _normalizeSubjects(
        List<dynamic>.from(updates['subjects'] as List),
      );
    }
    if (updates.containsKey('schedule')) {
      updates['schedule'] = _normalizeSchedule(
        List<dynamic>.from(updates['schedule'] as List),
      );
    }

    String? nextPhotoUrl = updates['photoUrl'] as String?;

    if (newProfileImageBytes != null && newProfileImageBytes.isNotEmpty) {
      nextPhotoUrl = await _uploadTutorImage(
        tutorId: tutorId,
        data: newProfileImageBytes,
      );
      updates['photoUrl'] = nextPhotoUrl;
    } else if (removePhoto) {
      await _deleteTutorImage(tutorId);
      updates['photoUrl'] = null;
      nextPhotoUrl = null;
    }

    await _tutorCollection.doc(tutorId).set(updates, SetOptions(merge: true));

    return TutorUpdateResult(photoUrl: nextPhotoUrl);
  }

  Future<bool> deleteTutor({
    required String tutorId,
    required String email,
    required String password,
  }) async {
    try {
      await _tutorCollection.doc(tutorId).delete();
      await _deleteTutorImage(tutorId);

      final FirebaseAuth secondaryAuth = await _createSecondaryAuth();
      try {
        final UserCredential credential =
            await secondaryAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        final User? user = credential.user;
        if (user != null) {
          await user.delete();
        }
      } finally {
        await secondaryAuth.signOut();
      }
      return true;
    } on FirebaseAuthException catch (error) {
      debugPrint('Delete tutor auth error: ${error.code} ${error.message}');
      return false;
    } on FirebaseException catch (error) {
      debugPrint('Delete tutor data error: ${error.code} ${error.message}');
      return false;
    }
  }

  List<String> _normalizeSubjects(List<dynamic> subjects) {
    return subjects
        .map((dynamic subject) => subject?.toString().trim() ?? '')
        .where((String subject) => subject.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _normalizeSchedule(List<dynamic> schedule) {
    return schedule
        .map((dynamic block) {
          if (block is Map<String, dynamic>) {
            return Map<String, dynamic>.from(block);
          }
          if (block is Map) {
            return Map<String, dynamic>.from(block.cast<String, dynamic>());
          }
          return <String, dynamic>{};
        })
        .where((Map<String, dynamic> block) => block.isNotEmpty)
        .toList();
  }

  Future<String> _uploadTutorImage({
    required String tutorId,
    required Uint8List data,
  }) async {
    final Reference ref = _storage.ref('tutors/$tutorId/profile.jpg');
    final SettableMetadata metadata =
        SettableMetadata(contentType: 'image/jpeg');
    final UploadTask uploadTask = ref.putData(data, metadata);
    await uploadTask.whenComplete(() {});
    return ref.getDownloadURL();
  }

  Future<void> _deleteTutorImage(String tutorId) async {
    final Reference ref = _storage.ref('tutors/$tutorId/profile.jpg');
    try {
      await ref.delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Future<FirebaseAuth> _createSecondaryAuth() async {
    final FirebaseAuth secondary = FirebaseAuth.instanceFor(app: _auth.app);
    if (kIsWeb) {
      await secondary.setPersistence(Persistence.NONE);
    }
    return secondary;
  }
}
