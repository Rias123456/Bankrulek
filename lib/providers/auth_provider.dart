import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/tutor.dart';
import '../services/tutor_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({required TutorService tutorService})
      : _tutorService = tutorService {
    _init();
  }

  static const String _adminPassword = '******';
  static const String _sessionKey = 'currentTutorId';

  final TutorService _tutorService;
  final List<Tutor> _tutors = <Tutor>[];

  SharedPreferences? _prefs;
  Tutor? _currentTutor;
  bool _isAdminLoggedIn = false;
  bool _isInitializing = true;
  bool _isLoading = false;

  bool get isLoading => _isInitializing || _isLoading;
  List<Tutor> get tutors => List.unmodifiable(_tutors);
  Tutor? get currentTutor => _currentTutor;
  bool get isTutorLoggedIn => _currentTutor != null;
  bool get isAdminLoggedIn => _isAdminLoggedIn;

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadTutorsInternal();
      final String? storedId = _prefs?.getString(_sessionKey);
      if (storedId != null && storedId.isNotEmpty) {
        _currentTutor = _findTutorById(storedId) ??
            await _tutorService.fetchTutorById(storedId);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to initialise AuthProvider: $error');
      debugPrint('$stackTrace');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshTutors() async {
    _setLoading(true);
    try {
      await _loadTutorsInternal();
      if (_currentTutor != null) {
        final Tutor? refreshed = _findTutorById(_currentTutor!.id);
        if (refreshed != null) {
          _currentTutor = refreshed;
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to refresh tutors: $error');
      debugPrint('$stackTrace');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> registerTutor({
    String fullName = '',
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
    final String normalizedEmail = email.trim().toLowerCase();
    final bool emailExists = _tutors.any(
      (Tutor tutor) => tutor.email.toLowerCase() == normalizedEmail,
    );
    if (emailExists) {
      return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
    }
    _setLoading(true);
    try {
      final Tutor tutor = await _tutorService.addTutor(
        fullName: fullName,
        nickname: nickname,
        phoneNumber: phoneNumber,
        lineId: lineId,
        email: email,
        password: password,
        currentActivity: currentActivity,
        status: status,
        travelTime: travelTime,
        subjects: subjects,
        schedule: schedule,
        photoBytes: photoBytes,
        photoBase64: photoBase64,
      );
      _tutors.add(tutor);
      return null;
    } catch (error, stackTrace) {
      debugPrint('Failed to register tutor: $error');
      debugPrint('$stackTrace');
      return 'เกิดข้อผิดพลาด ไม่สามารถสมัครสมาชิกได้';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> loginTutor({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final Tutor? tutor = await _tutorService.fetchTutorByEmailAndPassword(
        email,
        password,
      );
      if (tutor == null) {
        return 'ไม่พบผู้ใช้ / Invalid email or password';
      }
      _currentTutor = tutor;
      _isAdminLoggedIn = false;
      await _persistTutorId(tutor.id);
      if (_findTutorById(tutor.id) == null) {
        _tutors.add(tutor);
      }
      return null;
    } catch (error, stackTrace) {
      debugPrint('Failed to login tutor: $error');
      debugPrint('$stackTrace');
      return 'เกิดข้อผิดพลาด ${error.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> loginAdmin({required String password}) async {
    if (password == _adminPassword) {
      _isAdminLoggedIn = true;
      _currentTutor = null;
      await _persistTutorId(null);
      notifyListeners();
      return null;
    }
    return 'ข้อมูลไม่ถูกต้อง / Invalid admin credentials';
  }

  Future<void> logout() async {
    _currentTutor = null;
    _isAdminLoggedIn = false;
    await _persistTutorId(null);
    notifyListeners();
  }

  Future<String?> updateTutor({
    required Tutor updatedTutor,
    Uint8List? photoBytes,
    String? photoBase64,
  }) async {
    final Tutor? existing = _findTutorById(updatedTutor.id);
    if (existing == null) {
      return 'ไม่พบผู้ใช้ / Tutor not found';
    }
    final String originalEmail = existing.email.toLowerCase();
    final String newEmail = updatedTutor.email.trim().toLowerCase();
    if (originalEmail != newEmail) {
      final bool emailExists = _tutors.any(
        (Tutor tutor) =>
            tutor.id != updatedTutor.id && tutor.email.toLowerCase() == newEmail,
      );
      if (emailExists) {
        return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
      }
    }
    _setLoading(true);
    try {
      final Tutor saved = await _tutorService.updateTutor(
        updatedTutor,
        photoBytes: photoBytes,
        photoBase64: photoBase64,
      );
      final int index = _tutors.indexWhere((Tutor tutor) => tutor.id == saved.id);
      if (index >= 0) {
        _tutors[index] = saved;
      } else {
        _tutors.add(saved);
      }
      if (_currentTutor != null && _currentTutor!.id == saved.id) {
        _currentTutor = saved;
        await _persistTutorId(saved.id);
      }
      return null;
    } catch (error, stackTrace) {
      debugPrint('Failed to update tutor: $error');
      debugPrint('$stackTrace');
      return 'เกิดข้อผิดพลาด ${error.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteTutor(String tutorId) async {
    _setLoading(true);
    try {
      await _tutorService.deleteTutor(tutorId);
      final int index = _tutors.indexWhere((Tutor tutor) => tutor.id == tutorId);
      if (index >= 0) {
        _tutors.removeAt(index);
      }
      if (_currentTutor != null && _currentTutor!.id == tutorId) {
        _currentTutor = null;
        await _persistTutorId(null);
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to delete tutor: $error');
      debugPrint('$stackTrace');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void impersonateTutor(Tutor tutor) {
    _currentTutor = tutor;
    notifyListeners();
  }

  Future<void> _loadTutorsInternal() async {
    final List<Tutor> results = await _tutorService.fetchTutors();
    _tutors
      ..clear()
      ..addAll(results);
  }

  Tutor? _findTutorById(String id) {
    for (final Tutor tutor in _tutors) {
      if (tutor.id == id) {
        return tutor;
      }
    }
    return null;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _persistTutorId(String? tutorId) async {
    final SharedPreferences? prefs = _prefs;
    if (prefs == null) {
      return;
    }
    if (tutorId == null || tutorId.isEmpty) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, tutorId);
    }
  }
}
