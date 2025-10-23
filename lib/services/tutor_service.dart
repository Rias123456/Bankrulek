import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// ผลลัพธ์จากการอัปเดตข้อมูลติวเตอร์ ซึ่งจะบอก URL/พาธรูปภาพล่าสุด
class TutorUpdateResult {
  const TutorUpdateResult({
    this.photoUrl,
    this.photoPath,
  });

  final String? photoUrl;
  final String? photoPath;
}

/// บริการสำหรับจัดการข้อมูลติวเตอร์กับ Firebase
class TutorService {
  TutorService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseApp? _secondaryApp;
  FirebaseAuth? _secondaryAuth;

  CollectionReference<Map<String, dynamic>> get _tutorCollection =>
      _firestore.collection('tutors');

  /// ดึงข้อมูลเอกสารของติวเตอร์ตามไอดี
  Future<Map<String, dynamic>?> fetchTutorDocument(String tutorId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _tutorCollection.doc(tutorId).get();
    return snapshot.data();
  }

  /// สตรีมรายการติวเตอร์ทั้งหมดแบบเรียลไทม์
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTutors() {
    return _tutorCollection.snapshots();
  }

  /// สร้างข้อมูลติวเตอร์ใหม่ใน Firestore พร้อมอัปโหลดรูปโปรไฟล์หากมี
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
    required List<Map<String, dynamic>> schedule,
    String scheduleSerialized = '',
    Uint8List? profileImageBytes,
  }) async {
    final List<String> normalizedSubjects = subjects
        .map((String subject) => subject.trim())
        .where((String subject) => subject.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> normalizedSchedule =
        _normalizeSchedule(schedule);

    String? photoUrl;
    String? photoPath;
    if (profileImageBytes != null && profileImageBytes.isNotEmpty) {
      final _UploadResult upload = await _uploadTutorImage(
        tutorId: tutorId,
        data: profileImageBytes,
      );
      photoUrl = upload.url;
      photoPath = upload.path;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'fullName': fullName,
      'nickname': nickname,
      'phone': phone,
      'lineId': lineId,
      'email': email,
      'password': password,
      'photoUrl': photoUrl,
      'photoPath': photoPath,
      'currentStatus': currentStatus,
      'travelTime': travelTime,
      'subjects': normalizedSubjects,
      'schedule': normalizedSchedule,
      'scheduleSerialized': scheduleSerialized,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _tutorCollection.doc(tutorId).set(payload);
  }

  /// อัปเดตข้อมูลติวเตอร์ใน Firestore พร้อมจัดการรูปใหม่หรือการลบรูป
  Future<TutorUpdateResult> updateTutor({
    required String tutorId,
    required Map<String, dynamic> data,
    Uint8List? newProfileImageBytes,
    bool removePhoto = false,
    String? existingPhotoPath,
  }) async {
    String? nextPhotoUrl;
    String? nextPhotoPath;

    if (newProfileImageBytes != null && newProfileImageBytes.isNotEmpty) {
      if (existingPhotoPath != null && existingPhotoPath.isNotEmpty) {
        await _deleteStoragePath(existingPhotoPath);
      }
      final _UploadResult upload = await _uploadTutorImage(
        tutorId: tutorId,
        data: newProfileImageBytes,
      );
      nextPhotoUrl = upload.url;
      nextPhotoPath = upload.path;
      data['photoUrl'] = nextPhotoUrl;
      data['photoPath'] = nextPhotoPath;
    } else if (removePhoto) {
      if (existingPhotoPath != null && existingPhotoPath.isNotEmpty) {
        await _deleteStoragePath(existingPhotoPath);
      }
      data['photoUrl'] = null;
      data['photoPath'] = null;
    }

    if (data.containsKey('subjects')) {
      final dynamic rawSubjects = data['subjects'];
      if (rawSubjects is List) {
        data['subjects'] = rawSubjects
            .map((dynamic subject) => subject.toString().trim())
            .where((String subject) => subject.isNotEmpty)
            .toList();
      }
    }

    if (data.containsKey('schedule')) {
      final dynamic rawSchedule = data['schedule'];
      if (rawSchedule is List) {
        data['schedule'] = _normalizeSchedule(
          rawSchedule.cast<Map<String, dynamic>>(),
        );
      }
    }

    data['updatedAt'] = FieldValue.serverTimestamp();

    await _tutorCollection.doc(tutorId).set(data, SetOptions(merge: true));

    return TutorUpdateResult(
      photoUrl: nextPhotoUrl ??
          (removePhoto ? null : data['photoUrl'] as String?),
      photoPath: nextPhotoPath ??
          (removePhoto ? null : data['photoPath'] as String?),
    );
  }

  /// อัปเดตรหัสผ่านหรืออีเมลของบัญชีผู้ใช้ใน Firebase Auth
  Future<String?> updateTutorAuthCredentials({
    required String oldEmail,
    required String oldPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    final String trimmedEmail = newEmail?.trim() ?? '';
    final bool shouldUpdateEmail = trimmedEmail.isNotEmpty &&
        trimmedEmail.toLowerCase() != oldEmail.toLowerCase();
    final bool shouldUpdatePassword = newPassword != null &&
        newPassword.isNotEmpty &&
        newPassword != oldPassword;

    if (!shouldUpdateEmail && !shouldUpdatePassword) {
      return null;
    }

    try {
      final FirebaseAuth auth = await _ensureSecondaryAuth();
      final UserCredential credential = await auth.signInWithEmailAndPassword(
        email: oldEmail,
        password: oldPassword,
      );
      final User? user = credential.user;
      if (user == null) {
        await auth.signOut();
        return 'ไม่พบบัญชีผู้ใช้สำหรับอัปเดต';
      }
      if (shouldUpdateEmail) {
        await user.updateEmail(trimmedEmail);
      }
      if (shouldUpdatePassword) {
        await user.updatePassword(newPassword!);
      }
      await user.reload();
      await auth.signOut();
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthException(error);
    } catch (error) {
      return error.toString();
    }
  }

  /// ลบบัญชีติวเตอร์ทั้งใน Firestore และ Firebase Auth (หากมีข้อมูลรหัสผ่าน)
  Future<bool> deleteTutor({
    required String tutorId,
    String? email,
    String? password,
    String? photoPath,
  }) async {
    try {
      await _tutorCollection.doc(tutorId).delete();
    } on FirebaseException catch (error) {
      debugPrint('Failed to delete tutor document: ${error.message}');
      return false;
    }

    if (photoPath != null && photoPath.isNotEmpty) {
      await _deleteStoragePath(photoPath);
    }

    if (email != null && email.isNotEmpty &&
        password != null && password.isNotEmpty) {
      await deleteTutorAccount(email: email, password: password);
    }

    return true;
  }

  /// ลบบัญชีผู้ใช้ใน Firebase Auth โดยใช้ข้อมูลล็อกอินที่เก็บไว้
  Future<String?> deleteTutorAccount({
    required String email,
    required String password,
  }) async {
    try {
      final FirebaseAuth auth = await _ensureSecondaryAuth();
      final UserCredential credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        await auth.signOut();
        return 'ไม่พบบัญชีสำหรับลบ';
      }
      await user.delete();
      await auth.signOut();
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthException(error);
    } catch (error) {
      return error.toString();
    }
  }

  Future<_UploadResult> _uploadTutorImage({
    required String tutorId,
    required Uint8List data,
  }) async {
    final String fileName =
        'tutor_profiles/$tutorId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = _storage.ref(fileName);
    final SettableMetadata metadata =
        SettableMetadata(contentType: 'image/jpeg');
    final TaskSnapshot snapshot = await ref.putData(data, metadata);
    final String downloadUrl = await snapshot.ref.getDownloadURL();
    return _UploadResult(url: downloadUrl, path: fileName);
  }

  Future<void> _deleteStoragePath(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (_) {
      // Ignore missing files to keep workflow smooth.
    }
  }

  List<Map<String, dynamic>> _normalizeSchedule(
    List<Map<String, dynamic>> schedule,
  ) {
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> entry in schedule) {
      result.add(Map<String, dynamic>.from(entry));
    }
    return result;
  }

  Future<FirebaseAuth> _ensureSecondaryAuth() async {
    if (_secondaryAuth != null) {
      return _secondaryAuth!;
    }

    final FirebaseApp defaultApp = Firebase.app();
    try {
      _secondaryApp = Firebase.app('tutor-service-helper');
    } on FirebaseException catch (error) {
      if (error.code == 'no-app') {
        _secondaryApp = await Firebase.initializeApp(
          name: 'tutor-service-helper',
          options: defaultApp.options,
        );
      } else {
        rethrow;
      }
    }

    _secondaryAuth = FirebaseAuth.instanceFor(app: _secondaryApp!);
    return _secondaryAuth!;
  }

  String _mapAuthException(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return 'ไม่พบบัญชีผู้ใช้';
      case 'wrong-password':
        return 'รหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้แล้ว';
      case 'weak-password':
        return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'requires-recent-login':
        return 'กรุณาเข้าสู่ระบบใหม่ก่อนทำรายการ';
      default:
        return error.message ?? 'เกิดข้อผิดพลาดไม่ทราบสาเหตุ';
    }
  }
}

class _UploadResult {
  const _UploadResult({
    required this.url,
    required this.path,
  });

  final String url;
  final String path;
}
