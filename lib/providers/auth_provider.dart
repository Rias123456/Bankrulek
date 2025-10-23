import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/tutor_service.dart';

DateTime? _timestampToDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

int? _coerceInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

int? _timeToMinutes(String? value) {
  if (value == null) {
    return null;
  }
  final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final int? hour = int.tryParse(match.group(1)!);
  final int? minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) {
    return null;
  }
  return hour * 60 + minute;
}

int _dayIndexFromWeekday(int weekday) {
  return (weekday - DateTime.saturday + 7) % 7;
}

/// โมเดลข้อมูลติวเตอร์สำหรับใช้งานในแอป
class Tutor {
  static const String defaultStatus = 'เป็นครูอยู่';
  static const String defaultTravelDuration = '';
  static const List<String> statuses = <String>[
    defaultStatus,
    'พักการสอน',
  ];

  static const int _scheduleStartHour = 8;
  static const int _scheduleEndHour = 20;
  static const int _minutesPerSlot = 30;

  const Tutor({
    required this.id,
    this.fullName = '',
    this.nickname = '',
    this.phoneNumber = '',
    this.lineId = '',
    this.email = '',
    this.password = '',
    this.status = defaultStatus,
    this.travelDuration = defaultTravelDuration,
    this.currentActivity = '',
    this.profileImageBase64,
    this.photoUrl,
    this.photoPath,
    this.subjects = const <String>[],
    this.schedule = const <Map<String, dynamic>>[],
    this.teachingSchedule,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String fullName;
  final String nickname;
  final String phoneNumber;
  final String lineId;
  final String email;
  final String password;
  final String status;
  final String travelDuration;
  final String currentActivity;
  final String? profileImageBase64;
  final String? photoUrl;
  final String? photoPath;
  final List<String> subjects;
  final List<Map<String, dynamic>> schedule;
  final String? teachingSchedule;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Tutor.fromFirestore(String id, Map<String, dynamic> data) {
    final List<String> subjects = ((data['subjects'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic value) => value?.toString() ?? '')
        .where((String value) => value.isNotEmpty)
        .toList();
    final List<Map<String, dynamic>> schedule = ((data['schedule'] as List<dynamic>?) ?? <dynamic>[])
        .map((dynamic entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
    final String? serializedSchedule = (data['scheduleSerialized'] as String?)?.trim();
    final String resolvedStatus = (data['currentStatus'] as String?)?.trim().isNotEmpty == true
        ? (data['currentStatus'] as String).trim()
        : defaultStatus;
    final String resolvedTravel = (data['travelTime'] as String?)?.trim() ?? '';

    return Tutor(
      id: id,
      fullName: data['fullName'] as String? ?? '',
      nickname: data['nickname'] as String? ?? '',
      phoneNumber: data['phone'] as String? ?? '',
      lineId: data['lineId'] as String? ?? '',
      email: data['email'] as String? ?? '',
      password: data['password'] as String? ?? '',
      status: resolvedStatus.isEmpty ? defaultStatus : resolvedStatus,
      travelDuration: resolvedTravel,
      currentActivity: data['currentStatus'] as String? ?? '',
      profileImageBase64: null,
      photoUrl: data['photoUrl'] as String?,
      photoPath: data['photoPath'] as String?,
      subjects: subjects,
      schedule: schedule,
      teachingSchedule: serializedSchedule != null && serializedSchedule.isNotEmpty
          ? serializedSchedule
          : buildSerializedSchedule(schedule),
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
    );
  }

  Tutor copyWith({
    String? id,
    String? fullName,
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? status,
    String? travelDuration,
    String? currentActivity,
    String? profileImageBase64,
    String? photoUrl,
    String? photoPath,
    List<String>? subjects,
    List<Map<String, dynamic>>? schedule,
    String? teachingSchedule,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tutor(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      travelDuration: travelDuration ?? this.travelDuration,
      currentActivity: currentActivity ?? this.currentActivity,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      photoUrl: photoUrl ?? this.photoUrl,
      photoPath: photoPath ?? this.photoPath,
      subjects: subjects ?? List<String>.from(this.subjects),
      schedule: schedule ?? List<Map<String, dynamic>>.from(this.schedule),
      teachingSchedule: teachingSchedule ?? this.teachingSchedule,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? buildSerializedSchedule(List<Map<String, dynamic>> schedule) {
    if (schedule.isEmpty) {
      return '';
    }
    final List<Map<String, dynamic>> blocks = <Map<String, dynamic>>[];
    int nextId = 1;
    for (final Map<String, dynamic> entry in schedule) {
      final int? weekday = _coerceInt(entry['day']) ?? _coerceInt(entry['weekday']);
      final String? start = entry['start'] as String?;
      final String? end = entry['end'] as String?;
      if (weekday == null || start == null || end == null) {
        continue;
      }
      final int? startMinutes = _timeToMinutes(start);
      final int? endMinutes = _timeToMinutes(end);
      if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
        continue;
      }
      final int startSlot = ((startMinutes - _scheduleStartHour * 60) / _minutesPerSlot).floor();
      final int durationSlots = ((endMinutes - startMinutes) / _minutesPerSlot).ceil();
      if (startSlot < 0 || durationSlots <= 0) {
        continue;
      }
      final int dayIndex = _dayIndexFromWeekday(weekday);
      blocks.add(<String, dynamic>{
        'id': nextId++,
        'day': dayIndex,
        'start': startSlot,
        'duration': durationSlots,
        'type': 'teaching',
        if (entry['studentName'] != null && entry['studentName'].toString().trim().isNotEmpty)
          'note': entry['studentName'].toString(),
        if (entry['isRecurring'] != null) 'isRecurring': entry['isRecurring'],
        if (entry['date'] != null) 'date': entry['date'],
      });
    }
    if (blocks.isEmpty) {
      return '';
    }
    final Map<String, dynamic> payload = <String, dynamic>{
      'format': 'grid-v1',
      'startHour': _scheduleStartHour,
      'endHour': _scheduleEndHour,
      'minutesPerSlot': _minutesPerSlot,
      'blocks': blocks,
    };
    return 'SCHEDULE_V1:${jsonEncode(payload)}';
  }
}

/// ตัวจัดการสถานะการยืนยันตัวตนและข้อมูลติวเตอร์
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FirebaseAuth? auth,
    TutorService? tutorService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _tutorService = tutorService ?? TutorService() {
    _initialize();
  }

  static const String _adminPassword = '******';

  final FirebaseAuth _auth;
  final TutorService _tutorService;

  final List<Tutor> _tutors = <Tutor>[];
  Tutor? _currentTutor;
  bool _isAdminLoggedIn = false;
  bool _isLoading = true;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tutorStreamSubscription;

  bool _authReady = false;
  bool _tutorStreamReady = false;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  List<Tutor> get tutors => List.unmodifiable(_tutors);
  Tutor? get currentTutor => _currentTutor;
  bool get isTutorLoggedIn => _currentTutor != null;
  bool get isAdminLoggedIn => _isAdminLoggedIn;

  void _initialize() {
    _authSubscription = _auth.authStateChanges().listen(_handleAuthStateChanged);
    _tutorStreamSubscription = _tutorService.watchTutors().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<Tutor> nextTutors = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                Tutor.fromFirestore(doc.id, doc.data()))
            .toList();
        _tutors
          ..clear()
          ..addAll(nextTutors);
        _tutorStreamReady = true;
        _updateLoadingStatus();
        _notifySafely();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Failed to watch tutors: $error');
        _tutorStreamReady = true;
        _updateLoadingStatus();
        _notifySafely();
      },
    );
  }

  void _handleAuthStateChanged(User? user) {
    if (_disposed) {
      return;
    }
    if (user == null) {
      _currentTutor = null;
      _authReady = true;
      _updateLoadingStatus();
      _notifySafely();
      return;
    }
    _loadCurrentTutor(user);
  }

  Future<void> _loadCurrentTutor(User user) async {
    try {
      final Map<String, dynamic>? data =
          await _tutorService.fetchTutorDocument(user.uid);
      if (_disposed) {
        return;
      }
      if (data == null) {
        _currentTutor = null;
      } else {
        _currentTutor = Tutor.fromFirestore(user.uid, data);
      }
      _isAdminLoggedIn = false;
    } catch (error) {
      if (!_disposed) {
        debugPrint('Failed to load tutor profile: $error');
        _currentTutor = null;
      }
    }
    _authReady = true;
    _updateLoadingStatus();
    _notifySafely();
  }

  Future<String?> registerTutor({
    required String nickname,
    required String phoneNumber,
    required String lineId,
    required String email,
    required String password,
    String? profileImageBase64,
  }) async {
    UserCredential? credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        return 'ไม่สามารถสร้างบัญชีได้';
      }
      Uint8List? imageBytes;
      if (profileImageBase64 != null && profileImageBase64.isNotEmpty) {
        try {
          imageBytes = base64Decode(profileImageBase64);
        } catch (_) {
          imageBytes = null;
        }
      }
      await _tutorService.addTutor(
        tutorId: user.uid,
        fullName: '',
        nickname: nickname.trim(),
        phone: phoneNumber.trim(),
        lineId: lineId.trim(),
        email: email.trim(),
        password: password,
        currentStatus: Tutor.defaultStatus,
        travelTime: Tutor.defaultTravelDuration,
        subjects: const <String>[],
        schedule: const <Map<String, dynamic>>[],
        scheduleSerialized: '',
        profileImageBytes: imageBytes,
      );
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthError(error);
    } catch (error) {
      debugPrint('Failed to register tutor: $error');
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // ignore cleanup errors
        }
      }
      return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }

  Future<String?> loginTutor({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _isAdminLoggedIn = false;
      return null;
    } on FirebaseAuthException catch (error) {
      return _mapAuthError(error);
    } catch (error) {
      debugPrint('Tutor login failed: $error');
      return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }

  Future<String?> loginAdmin({
    required String password,
  }) async {
    if (password == _adminPassword) {
      _isAdminLoggedIn = true;
      _currentTutor = null;
      _notifySafely();
      return null;
    }
    return 'ข้อมูลไม่ถูกต้อง / Invalid admin credentials';
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (error) {
      debugPrint('Failed to sign out: $error');
    }
    _currentTutor = null;
    _isAdminLoggedIn = false;
    _notifySafely();
  }

  void impersonateTutor(Tutor tutor) {
    _currentTutor = tutor;
    _notifySafely();
  }

  Future<String?> updateTutor({
    required String originalEmail,
    required Tutor updatedTutor,
  }) async {
    final Tutor? existing = _findTutorByEmail(originalEmail);
    if (existing == null) {
      return 'ไม่พบผู้ใช้ / Tutor not found';
    }
    final bool emailChanged =
        updatedTutor.email.trim().toLowerCase() != existing.email.toLowerCase();
    final bool passwordChanged = updatedTutor.password != existing.password;

    if ((emailChanged || passwordChanged) && existing.password.isEmpty) {
      return 'ไม่สามารถอัปเดตข้อมูลการเข้าสู่ระบบได้';
    }

    if (emailChanged || passwordChanged) {
      final String? authError = await _tutorService.updateTutorAuthCredentials(
        oldEmail: existing.email,
        oldPassword: existing.password,
        newEmail: emailChanged ? updatedTutor.email.trim() : null,
        newPassword: passwordChanged ? updatedTutor.password : null,
      );
      if (authError != null) {
        return authError;
      }
    }

    final Map<String, dynamic> data = <String, dynamic>{
      'fullName': updatedTutor.fullName,
      'nickname': updatedTutor.nickname,
      'phone': updatedTutor.phoneNumber,
      'lineId': updatedTutor.lineId,
      'email': updatedTutor.email,
      'password': updatedTutor.password,
      'currentStatus': updatedTutor.status,
      'travelTime': updatedTutor.travelDuration,
      'subjects': updatedTutor.subjects,
      'schedule': updatedTutor.schedule,
      'scheduleSerialized': updatedTutor.teachingSchedule,
    };

    try {
      final TutorUpdateResult result = await _tutorService.updateTutor(
        tutorId: existing.id,
        data: data,
        existingPhotoPath: updatedTutor.photoPath ?? existing.photoPath,
      );
      final Tutor merged = existing.copyWith(
        fullName: updatedTutor.fullName,
        nickname: updatedTutor.nickname,
        phoneNumber: updatedTutor.phoneNumber,
        lineId: updatedTutor.lineId,
        email: updatedTutor.email,
        password: updatedTutor.password,
        status: updatedTutor.status,
        travelDuration: updatedTutor.travelDuration,
        currentActivity: updatedTutor.currentActivity,
        subjects: List<String>.from(updatedTutor.subjects),
        schedule: List<Map<String, dynamic>>.from(updatedTutor.schedule),
        teachingSchedule: updatedTutor.teachingSchedule,
        photoUrl: result.photoUrl ?? existing.photoUrl,
        photoPath: result.photoPath ?? existing.photoPath,
      );
      _replaceTutor(merged);
      return null;
    } on FirebaseException catch (error) {
      return error.message ?? 'ไม่สามารถอัปเดตข้อมูลได้';
    } catch (error) {
      debugPrint('Failed to update tutor: $error');
      return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }

  Future<bool> deleteTutor(String email) async {
    final Tutor? existing = _findTutorByEmail(email);
    if (existing == null) {
      return false;
    }
    try {
      final bool deleted = await _tutorService.deleteTutor(
        tutorId: existing.id,
        email: existing.email,
        password: existing.password,
        photoPath: existing.photoPath,
      );
      if (!deleted) {
        return false;
      }
      _tutors.removeWhere((Tutor tutor) => tutor.id == existing.id);
      if (_currentTutor?.id == existing.id) {
        _currentTutor = null;
      }
      _notifySafely();
      return true;
    } catch (error) {
      debugPrint('Failed to delete tutor: $error');
      return false;
    }
  }

  Tutor? _findTutorByEmail(String email) {
    final String target = email.toLowerCase().trim();
    for (final Tutor tutor in _tutors) {
      if (tutor.email.toLowerCase() == target) {
        return tutor;
      }
    }
    return null;
  }

  void _replaceTutor(Tutor tutor) {
    final int index = _tutors.indexWhere((Tutor element) => element.id == tutor.id);
    if (index == -1) {
      _tutors.add(tutor);
    } else {
      _tutors[index] = tutor;
    }
    if (_currentTutor != null && _currentTutor!.id == tutor.id) {
      _currentTutor = tutor;
    }
    _notifySafely();
  }

  void _updateLoadingStatus() {
    _isLoading = !(_authReady && _tutorStreamReady);
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
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
      case 'too-many-requests':
        return 'มีการพยายามล็อกอินหลายครั้ง โปรดลองอีกครั้งภายหลัง';
      default:
        return error.message ?? 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _tutorStreamSubscription?.cancel();
    super.dispose();
  }
}
