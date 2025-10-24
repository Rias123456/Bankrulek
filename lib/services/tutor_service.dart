import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class TutorUpdateResult {
  const TutorUpdateResult({
    this.photoUrl,
    this.photoPath,
  });

  final String? photoUrl;
  final String? photoPath;
}

class _UploadResult {
  const _UploadResult({
    required this.url,
    required this.path,
  });

  final String url;
  final String path;
}

/// บริการจัดการข้อมูลติวเตอร์กับ Firebase Auth, Firestore และ Storage
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

  FirebaseAuth? _secondaryAuth;

  CollectionReference<Map<String, dynamic>> get _tutorCollection =>
      _firestore.collection('tutors');

  /// เข้าสู่ระบบด้วยอีเมลและรหัสผ่าน แล้วคืนค่า tutorId (uid)
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

  /// ออกจากระบบ Firebase Auth
// เพิ่มหลังบรรทัด 23 (หลัง method login)
Future<void> logout() async {
  await _auth.signOut();
}

  /// ดึงข้อมูลติวเตอร์จาก Firestore
  Future<Map<String, dynamic>?> getTutor(String tutorId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _tutorCollection.doc(tutorId).get();
    return snapshot.data();
  }

  /// ใช้สำหรับโค้ดที่ยังเรียกเมธอดเดิม fetchTutorDocument
  Future<Map<String, dynamic>?> fetchTutorDocument(String tutorId) {
    return getTutor(tutorId);
  }

  /// สตรีมรายชื่อติวเตอร์ทั้งหมดสำหรับหน้าแอดมิน
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTutors() {
    return _tutorCollection.orderBy('createdAt', descending: true).snapshots();
  }

  /// เพิ่มข้อมูลติวเตอร์ใหม่ลง Firestore และอัปโหลดรูปถ้ามี
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
    final List<String> normalizedSubjects =
        _normalizeSubjects(List<dynamic>.from(subjects));
    final List<Map<String, dynamic>> normalizedSchedule =
        _normalizeSchedule(List<dynamic>.from(schedule));

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

  /// อัปเดตข้อมูลติวเตอร์และจัดการรูปโปรไฟล์หากเปลี่ยนหรือลบออก
  Future<TutorUpdateResult> updateTutor({
    required String tutorId,
    required Map<String, dynamic> data,
    Uint8List? newProfileImageBytes,
    bool removePhoto = false,
    String? existingPhotoPath,
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

    String? nextPhotoUrl;
    String? nextPhotoPath = existingPhotoPath;

    if (newProfileImageBytes != null && newProfileImageBytes.isNotEmpty) {
      final _UploadResult upload = await _uploadTutorImage(
        tutorId: tutorId,
        data: newProfileImageBytes,
      );
      nextPhotoUrl = upload.url;
      nextPhotoPath = upload.path;
      updates['photoUrl'] = nextPhotoUrl;
      updates['photoPath'] = nextPhotoPath;
    } else if (removePhoto) {
      final String resolvedPath =
          existingPhotoPath ?? _profileStoragePath(tutorId);
      await _deleteStoragePath(resolvedPath);
      updates['photoUrl'] = null;
      updates['photoPath'] = null;
      nextPhotoUrl = null;
      nextPhotoPath = null;
    }

    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _tutorCollection.doc(tutorId).set(updates, SetOptions(merge: true));

    return TutorUpdateResult(
      photoUrl: nextPhotoUrl ?? updates['photoUrl'] as String?,
      photoPath: nextPhotoPath ?? updates['photoPath'] as String?,
    );
  }

  /// อัปเดตอีเมลหรือรหัสผ่านของบัญชีติวเตอร์ใน Firebase Auth
  Future<String?> updateTutorAuthCredentials({
    required String oldEmail,
    required String oldPassword,
    String? newEmail,
    String? newPassword,
  }) async {
    final String trimmedEmail = newEmail?.trim() ?? '';
    final bool shouldUpdateEmail = trimmedEmail.isNotEmpty &&
        trimmedEmail.toLowerCase() != oldEmail.toLowerCase();
    final bool shouldUpdatePassword =
        newPassword != null && newPassword.isNotEmpty && newPassword != oldPassword;

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
      await auth.signOut();
      return null;
    } on FirebaseAuthException catch (error) {
      return error.message ?? 'ไม่สามารถอัปเดตข้อมูลการเข้าสู่ระบบได้';
    }
  }

  /// ลบข้อมูลติวเตอร์ทั้งจาก Firestore, Storage และ Firebase Auth
  Future<bool> deleteTutor({
    required String tutorId,
    required String email,
    required String password,
    String? photoPath,
  }) async {
    try {
      await _tutorCollection.doc(tutorId).delete();
      final String resolvedPath = photoPath ?? _profileStoragePath(tutorId);
      await _deleteStoragePath(resolvedPath);

      final FirebaseAuth auth = await _ensureSecondaryAuth();
      final UserCredential credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = credential.user;
      if (user != null) {
        await user.delete();
      }
      await auth.signOut();
      return true;
    } on FirebaseAuthException catch (error) {
      debugPrint('Delete tutor auth error: ${error.message}');
      return false;
    } on FirebaseException catch (error) {
      debugPrint('Delete tutor storage/firestore error: ${error.message}');
      return false;
    }
  }

  List<String> _normalizeSubjects(List<dynamic> subjects) {
    return subjects
        .map((dynamic subject) => subject?.toString().trim() ?? '')
        .where((String subject) => subject.isNotEmpty)
        .toList();
  }

  List<Map<String, dynamic>> _normalizeSchedule(
    List<dynamic> schedule,
  ) {
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

  Future<_UploadResult> _uploadTutorImage({
    required String tutorId,
    required Uint8List data,
  }) async {
    final String path = _profileStoragePath(tutorId);
    final Reference ref = _storage.ref(path);
    final SettableMetadata metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );
    final UploadTask uploadTask = ref.putData(data, metadata);
    await uploadTask.whenComplete(() {});
    final String url = await ref.getDownloadURL();
    return _UploadResult(url: url, path: path);
  }

  Future<void> _deleteStoragePath(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  String _profileStoragePath(String tutorId) {
    return 'tutors/$tutorId/profile.jpg';
  }

  Future<FirebaseAuth> _ensureSecondaryAuth() async {
    if (_secondaryAuth != null) {
      return _secondaryAuth!;
    }
    final FirebaseAuth auth = FirebaseAuth.instanceFor(app: _auth.app);
    if (kIsWeb) {
      await auth.setPersistence(Persistence.NONE);
    }
    _secondaryAuth = auth;
    return auth;
  }
}
