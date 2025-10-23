import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// คลาสข้อมูลสำหรับเก็บรายละเอียดของติวเตอร์ / Data model for tutors
class Tutor {
  /// ไอดีเอกสารใน Firestore / Firestore document identifier
  final String id;

  /// ชื่อจริง / First name
  final String firstName;

  /// นามสกุล / Last name
  final String lastName;

  /// สิ่งที่กำลังทำอยู่ปัจจุบัน / Current activity or occupation
  final String currentActivity;

  /// ชื่อเล่น / Nickname
  final String nickname;

  /// เบอร์โทรศัพท์ที่ติดต่อได้ / Contact phone number
  final String phoneNumber;

  /// ไอดีไลน์ / Line ID
  final String lineId;

  /// อีเมลสำหรับล็อกอิน / Login email
  final String email;

  /// รหัสผ่านแบบ plaintext (ตัวอย่างเท่านั้น) / Plaintext password (for demo only)
  final String password;

  /// สถานะของติวเตอร์ / Tutor status label
  final String status;

  /// ระยะเวลาในการเดินทางไปสอน / Travel duration to tutoring location
  final String travelDuration;

  /// ลิงก์รูปโปรไฟล์ / Download URL for the profile image
  final String? profileImageUrl;

  /// พาธไฟล์รูปโปรไฟล์ใน Firebase Storage / Storage path for the profile image
  final String? profileImageStoragePath;

  /// วิชาที่สามารถสอนได้ พร้อมระดับชั้น / Subjects with the supported grade levels
  final List<String> subjects;

  /// รายละเอียดตารางสอน / Teaching schedule details
  final String? teachingSchedule;

  /// ค่าเริ่มต้นของสถานะ / Default tutor status label
  static const String defaultStatus = 'เป็นครูอยู่';

  /// รายการสถานะที่รองรับ / Supported tutor status options
  static const List<String> statuses = <String>[
    defaultStatus,
    'พักการสอน',
  ];

  /// ค่าเริ่มต้นของระยะเวลาเดินทาง / Default travel duration label
  static const String defaultTravelDuration = '';

  const Tutor({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.currentActivity = '',
    required this.nickname,
    required this.phoneNumber,
    required this.lineId,
    required this.email,
    required this.password,
    required this.status,
    required this.travelDuration,
    this.profileImageUrl,
    this.profileImageStoragePath,
    this.subjects = const <String>[],
    this.teachingSchedule,
  });

  /// สร้างอ็อบเจ็กต์จากเอกสารใน Firestore
  factory Tutor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      throw StateError('Tutor document ${doc.id} is missing data');
    }

    String readString(String key, {String defaultValue = ''}) {
      final Object? raw = data[key];
      if (raw is String) {
        return raw.trim();
      }
      return defaultValue;
    }

    String? readNullableString(String key) {
      final Object? raw = data[key];
      if (raw is String) {
        final String trimmed = raw.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    List<String> readStringList(String key) {
      final Object? raw = data[key];
      if (raw is List) {
        return raw
            .whereType<Object>()
            .map((Object value) => value.toString().trim())
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    final String resolvedStatus = readString('status').isEmpty
        ? defaultStatus
        : readString('status');
    final String resolvedTravelDuration =
        readString('travelDuration', defaultValue: defaultTravelDuration);

    return Tutor(
      id: doc.id,
      firstName: readString('firstName'),
      lastName: readString('lastName'),
      currentActivity: readString('currentActivity'),
      nickname: readString('nickname'),
      phoneNumber: readString('phoneNumber'),
      lineId: readString('lineId'),
      email: readString('email'),
      password: readString('password'),
      status: resolvedStatus.isEmpty ? defaultStatus : resolvedStatus,
      travelDuration: resolvedTravelDuration,
      profileImageUrl: readNullableString('profileImageUrl'),
      profileImageStoragePath: readNullableString('profileImageStoragePath'),
      subjects: readStringList('subjects'),
      teachingSchedule: readNullableString('teachingSchedule'),
    );
  }

  /// สร้างอ็อบเจ็กต์ใหม่โดยคงค่าเดิม / Copy with new field values
  Tutor copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? currentActivity,
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? status,
    String? travelDuration,
    String? profileImageUrl,
    String? profileImageStoragePath,
    List<String>? subjects,
    String? teachingSchedule,
    bool overrideTeachingSchedule = false,
  }) {
    return Tutor(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currentActivity: currentActivity ?? this.currentActivity,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      travelDuration: travelDuration ?? this.travelDuration,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImageStoragePath: profileImageStoragePath ?? this.profileImageStoragePath,
      subjects: subjects ?? this.subjects,
      teachingSchedule:
          overrideTeachingSchedule ? teachingSchedule : teachingSchedule ?? this.teachingSchedule,
    );
  }
}

/// ตัวจัดการสถานะการยืนยันตัวตน / Authentication state manager
class AuthProvider extends ChangeNotifier {
  static const String _tutorsCollection = 'tutors';

  /// อินสแตนซ์ Firestore ที่ใช้ในการบันทึกข้อมูล
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// อินสแตนซ์ Firebase Storage สำหรับเก็บไฟล์รูปภาพ
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// รายชื่อผู้สอนทั้งหมด / List of registered tutors
  final List<Tutor> _tutors = [];

  /// ติวเตอร์ที่กำลังล็อกอินอยู่ / Currently authenticated tutor
  Tutor? _currentTutor;

  /// สถานะว่าแอดมินล็อกอินแล้วหรือไม่ / Flag for admin login state
  bool _isAdminLoggedIn = false;

  /// สถานะการโหลดข้อมูล / Loading flag for IO operations
  bool _isLoading = true;

  /// subscription สำหรับฟังการเปลี่ยนแปลงของข้อมูลติวเตอร์
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tutorSubscription;

  /// อีเมลที่ต้องการกู้คืนเซสชันหลังโหลดข้อมูลเสร็จ
  String? _pendingSessionEmail;

  /// ข้อมูล credential ของแอดมินตัวอย่าง / Sample admin credential
  static const String _adminPassword = '******';

  /// คีย์ไฟล์บันทึกเซสชันติวเตอร์ / File name for tutor session persistence
  static const String _tutorSessionFileName = 'current_tutor_session.txt';

  /// สร้าง provider และโหลดข้อมูล / Constructor triggers loading data
  AuthProvider() {
    _initialize();
  }

  /// ส่งออกสถานะโหลด / Public getter for loading state
  bool get isLoading => _isLoading;

  /// ส่งออกรายชื่อติวเตอร์แบบอ่านอย่างเดียว / Unmodifiable tutor list
  List<Tutor> get tutors => List.unmodifiable(_tutors);

  /// ส่งออกผู้ใช้ติวเตอร์ปัจจุบัน / Currently logged-in tutor
  Tutor? get currentTutor => _currentTutor;

  /// ตรวจสอบว่าติวเตอร์ล็อกอินหรือยัง / Whether a tutor is logged in
  bool get isTutorLoggedIn => _currentTutor != null;

  /// ตรวจสอบว่าแอดมินล็อกอินหรือยัง / Whether admin is logged in
  bool get isAdminLoggedIn => _isAdminLoggedIn;

  /// ฟังก์ชันเริ่มต้นโหลดข้อมูล / Kick-start Firestore listeners
  void _initialize() {
    Future.microtask(() async {
      await _restoreTutorSession();
      _listenToTutorChanges();
    });
  }

  void _listenToTutorChanges() {
    _tutorSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _tutorSubscription = _firestore
        .collection(_tutorsCollection)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      _tutors
        ..clear()
        ..addAll(
          snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => Tutor.fromFirestore(doc)),
        );
      _isLoading = false;
      _syncCurrentTutorWithCache();
      _tryRestorePendingSession();
      notifyListeners();
    }, onError: (Object error) {
      debugPrint('Failed to listen tutors: $error');
      _isLoading = false;
      notifyListeners();
    });
  }

  Tutor? _findTutorByEmail(String email) {
    try {
      return _tutors.firstWhere(
        (Tutor tutor) => tutor.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _syncCurrentTutorWithCache() {
    if (_currentTutor == null) {
      return;
    }
    final Tutor? match = _findTutorByEmail(_currentTutor!.email);
    if (match != null) {
      _currentTutor = match;
    }
  }

  void _tryRestorePendingSession() {
    if (_pendingSessionEmail == null) {
      return;
    }
    final Tutor? match = _findTutorByEmail(_pendingSessionEmail!);
    if (match != null) {
      _currentTutor = match;
      _isAdminLoggedIn = false;
      _pendingSessionEmail = null;
    }
  }

  /// ตำแหน่งไฟล์บันทึกเซสชัน / Resolve persistent session file location
  Future<File> get _sessionFile async {
    final Directory dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_tutorSessionFileName');
  }

  Future<void> _restoreTutorSession() async {
    try {
      final File sessionFile = await _sessionFile;
      if (!await sessionFile.exists()) {
        _pendingSessionEmail = null;
        return;
      }
      final String savedEmail = (await sessionFile.readAsString()).trim();
      if (savedEmail.isEmpty) {
        _pendingSessionEmail = null;
        return;
      }
      _pendingSessionEmail = savedEmail;
    } catch (e) {
      debugPrint('Failed to restore tutor session: $e');
    }
  }

  /// สมัครสมาชิกติวเตอร์ / Register new tutor
  Future<String?> registerTutor({
    required String nickname,
    required String phoneNumber,
    required String lineId,
    required String email,
    required String password,
    String? profileImageBase64,
  }) async {
    final String trimmedEmail = email.trim();
    final String normalizedEmail = trimmedEmail.toLowerCase();
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_tutorsCollection)
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
      }

      String? imageUrl;
      String? storagePath;
      if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
        try {
          final _UploadedImage uploaded =
              await _uploadProfileImage(profileImageBase64, referenceEmail: trimmedEmail);
          imageUrl = uploaded.downloadUrl;
          storagePath = uploaded.storagePath;
        } on FormatException {
          return 'รูปโปรไฟล์ไม่ถูกต้อง / Invalid profile image data';
        } on FirebaseException catch (error) {
          return 'อัปโหลดรูปไม่สำเร็จ: ${error.message ?? error.code}';
        }
      }

      final DocumentReference<Map<String, dynamic>> docRef =
          _firestore.collection(_tutorsCollection).doc();
      await docRef.set(<String, dynamic>{
        'firstName': '',
        'lastName': '',
        'currentActivity': '',
        'nickname': nickname.trim(),
        'phoneNumber': phoneNumber.trim(),
        'lineId': lineId.trim(),
        'email': trimmedEmail,
        'emailLowercase': normalizedEmail,
        'password': password,
        'status': Tutor.defaultStatus,
        'travelDuration': Tutor.defaultTravelDuration,
        'profileImageUrl': imageUrl,
        'profileImageStoragePath': storagePath,
        'subjects': <String>[],
        'teachingSchedule': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('Failed to register tutor: $e');
      return 'เกิดข้อผิดพลาด ${e.toString()} / Unexpected error';
    }
  }

  /// ล็อกอินสำหรับติวเตอร์ / Tutor login method
  Future<String?> loginTutor({
    required String email,
    required String password,
  }) async {
    try {
      final String normalizedEmail = email.trim().toLowerCase();
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_tutorsCollection)
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return 'ไม่พบผู้ใช้ / Invalid email or password';
      }
      final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;
      final Map<String, dynamic>? data = doc.data();
      final String storedPassword = data?['password'] as String? ?? '';
      if (storedPassword != password) {
        return 'ไม่พบผู้ใช้ / Invalid email or password';
      }
      final Tutor tutor = Tutor.fromFirestore(doc);
      _currentTutor = tutor;
      _isAdminLoggedIn = false;
      _pendingSessionEmail = tutor.email;
      _updateTutorInCache(tutor);
      await _persistTutorSession(tutor.email);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Failed to login tutor: $e');
      return 'เกิดข้อผิดพลาด ${e.toString()} / Unexpected error';
    }
  }

  /// ล็อกอินสำหรับแอดมิน / Admin login method
  Future<String?> loginAdmin({
    required String password,
  }) async {
    if (password == _adminPassword) {
      _isAdminLoggedIn = true;
      _currentTutor = null;
      _pendingSessionEmail = null;
      await _persistTutorSession(null);
      notifyListeners();
      return null;
    }
    return 'ข้อมูลไม่ถูกต้อง / Invalid admin credentials';
  }

  /// ออกจากระบบทั้งหมด / Logout for both tutor and admin
  Future<void> logout() async {
    _currentTutor = null;
    _isAdminLoggedIn = false;
    _pendingSessionEmail = null;
    await _persistTutorSession(null);
    notifyListeners();
  }

  /// ให้แอดมินเลือกดูโปรไฟล์ติวเตอร์ / Allow admin to open a tutor profile
  void impersonateTutor(Tutor tutor) {
    _currentTutor = tutor;
    notifyListeners();
  }

  /// อัปเดตข้อมูลติวเตอร์ / Update tutor information
  Future<String?> updateTutor({
    required String originalEmail,
    required Tutor updatedTutor,
    String? newProfileImageBase64,
    bool removeProfileImage = false,
  }) async {
    final Tutor? existing = _findTutorByEmail(originalEmail);
    if (existing == null) {
      return 'ไม่พบผู้ใช้ / Tutor not found';
    }

    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection(_tutorsCollection).doc(existing.id);
    final String trimmedEmail = updatedTutor.email.trim();
    final String normalizedEmail = trimmedEmail.toLowerCase();

    if (normalizedEmail != existing.email.toLowerCase()) {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_tutorsCollection)
          .where('emailLowercase', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty && snapshot.docs.first.id != existing.id) {
        return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
      }
    }

    String? imageUrl = existing.profileImageUrl;
    String? storagePath = existing.profileImageStoragePath;

    if (removeProfileImage) {
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await _storage.ref(storagePath).delete();
        } on FirebaseException catch (error) {
          debugPrint('Failed to delete profile image: ${error.message ?? error.code}');
        }
      }
      imageUrl = null;
      storagePath = null;
    } else if (newProfileImageBase64 != null && newProfileImageBase64.isNotEmpty) {
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await _storage.ref(storagePath).delete();
        } on FirebaseException catch (error) {
          debugPrint('Failed to delete previous image: ${error.message ?? error.code}');
        }
      }
      try {
        final _UploadedImage uploaded =
            await _uploadProfileImage(newProfileImageBase64, referenceEmail: trimmedEmail);
        imageUrl = uploaded.downloadUrl;
        storagePath = uploaded.storagePath;
      } on FormatException {
        return 'รูปโปรไฟล์ไม่ถูกต้อง / Invalid profile image data';
      } on FirebaseException catch (error) {
        return 'อัปโหลดรูปไม่สำเร็จ: ${error.message ?? error.code}';
      }
    }

    final String resolvedStatus =
        updatedTutor.status.isEmpty ? Tutor.defaultStatus : updatedTutor.status;

    try {
      await docRef.update(<String, dynamic>{
        'firstName': updatedTutor.firstName.trim(),
        'lastName': updatedTutor.lastName.trim(),
        'currentActivity': updatedTutor.currentActivity.trim(),
        'nickname': updatedTutor.nickname.trim(),
        'phoneNumber': updatedTutor.phoneNumber.trim(),
        'lineId': updatedTutor.lineId.trim(),
        'email': trimmedEmail,
        'emailLowercase': normalizedEmail,
        'password': updatedTutor.password,
        'status': resolvedStatus,
        'travelDuration': updatedTutor.travelDuration.trim(),
        'subjects': List<String>.from(updatedTutor.subjects),
        'teachingSchedule': updatedTutor.teachingSchedule,
        'profileImageUrl': imageUrl,
        'profileImageStoragePath': storagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to update tutor: $e');
      return 'เกิดข้อผิดพลาด ${e.toString()} / Unexpected error';
    }

    final Tutor sanitized = existing.copyWith(
      firstName: updatedTutor.firstName.trim(),
      lastName: updatedTutor.lastName.trim(),
      currentActivity: updatedTutor.currentActivity.trim(),
      nickname: updatedTutor.nickname.trim(),
      phoneNumber: updatedTutor.phoneNumber.trim(),
      lineId: updatedTutor.lineId.trim(),
      email: trimmedEmail,
      password: updatedTutor.password,
      status: resolvedStatus,
      travelDuration: updatedTutor.travelDuration.trim(),
      subjects: List<String>.from(updatedTutor.subjects),
      teachingSchedule: updatedTutor.teachingSchedule,
      overrideTeachingSchedule: true,
      profileImageUrl: imageUrl,
      profileImageStoragePath: storagePath,
    );

    _updateTutorInCache(sanitized);

    bool shouldPersistSession = false;
    if (_currentTutor != null && _currentTutor!.id == existing.id) {
      _currentTutor = sanitized;
      shouldPersistSession = true;
    }

    if (shouldPersistSession) {
      await _persistTutorSession(sanitized.email);
    }

    notifyListeners();
    return null;
  }

  /// ลบข้อมูลติวเตอร์ออกจากระบบ / Delete tutor from storage
  Future<bool> deleteTutor(String email) async {
    final Tutor? target = _findTutorByEmail(email);
    if (target == null) {
      return false;
    }
    try {
      await _firestore.collection(_tutorsCollection).doc(target.id).delete();
      if (target.profileImageStoragePath != null && target.profileImageStoragePath!.isNotEmpty) {
        try {
          await _storage.ref(target.profileImageStoragePath!).delete();
        } on FirebaseException catch (error) {
          debugPrint('Failed to delete profile image: ${error.message ?? error.code}');
        }
      }
      _tutors.removeWhere((Tutor tutor) => tutor.id == target.id);
      if (_currentTutor != null && _currentTutor!.id == target.id) {
        _currentTutor = null;
        await _persistTutorSession(null);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to delete tutor: $e');
      return false;
    }
  }

  void _updateTutorInCache(Tutor tutor) {
    final int index = _tutors.indexWhere((Tutor element) => element.id == tutor.id);
    if (index == -1) {
      _tutors.add(tutor);
    } else {
      _tutors[index] = tutor;
    }
  }

  /// บันทึกเซสชันติวเตอร์ลงไฟล์ / Persist tutor session email to file
  Future<void> _persistTutorSession(String? email) async {
    try {
      final File sessionFile = await _sessionFile;
      if (email == null || email.trim().isEmpty) {
        if (await sessionFile.exists()) {
          await sessionFile.delete();
        }
        return;
      }
      await sessionFile.create(recursive: true);
      await sessionFile.writeAsString(email.trim());
    } catch (e) {
      debugPrint('Failed to persist tutor session: $e');
    }
  }

  String _generateStorageFileName(String email) {
    final String sanitized = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${sanitized}_$timestamp.jpg';
  }

  Future<_UploadedImage> _uploadProfileImage(
    String base64Data, {
    required String referenceEmail,
  }) async {
    final Uint8List bytes = base64Decode(base64Data);
    final String fileName = _generateStorageFileName(referenceEmail);
    final String storagePath = 'tutor_profiles/$fileName';
    final Reference ref = _storage.ref(storagePath);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final String downloadUrl = await ref.getDownloadURL();
    return _UploadedImage(downloadUrl: downloadUrl, storagePath: storagePath);
  }

  @override
  void dispose() {
    _tutorSubscription?.cancel();
    super.dispose();
  }
}

class _UploadedImage {
  const _UploadedImage({required this.downloadUrl, required this.storagePath});

  final String downloadUrl;
  final String storagePath;
}
