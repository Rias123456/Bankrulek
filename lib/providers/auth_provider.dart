import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// คลาสข้อมูลสำหรับเก็บรายละเอียดของติวเตอร์ / Data model for tutors
class Tutor {
  /// ชื่อเต็มของติวเตอร์ / Tutor full name
  final String name;

  /// อีเมลสำหรับล็อกอิน / Login email
  final String email;

  /// รหัสผ่านแบบ plaintext (ตัวอย่างเท่านั้น) / Plaintext password (for demo only)
  final String password;

  const Tutor({
    required this.name,
    required this.email,
    required this.password,
  });

  /// แปลงข้อมูลเป็น JSON / Convert to JSON map
  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password': password,
      };

  /// สร้าง Tutor จาก JSON / Factory constructor from JSON map
  factory Tutor.fromJson(Map<String, dynamic> json) => Tutor(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );
}

/// ตัวจัดการสถานะการยืนยันตัวตน / Authentication state manager
class AuthProvider extends ChangeNotifier {
  /// รายชื่อผู้สอนทั้งหมด / List of registered tutors
  final List<Tutor> _tutors = [];

  /// ติวเตอร์ที่กำลังล็อกอินอยู่ / Currently authenticated tutor
  Tutor? _currentTutor;

  /// สถานะว่าแอดมินล็อกอินแล้วหรือไม่ / Flag for admin login state
  bool _isAdminLoggedIn = false;

  /// สถานะการโหลดข้อมูลไฟล์ / Loading flag for IO operations
  bool _isLoading = true;

  /// ข้อมูล credential ของแอดมินตัวอย่าง / Sample admin credential
  static const String _adminEmail = 'admin@bankrulek.com';
  static const String _adminPassword = 'admin1234';

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

  /// ฟังก์ชันเริ่มต้นโหลดข้อมูล / Kick-start file loading
  void _initialize() {
    Future.microtask(() async {
      await _loadTutors();
    });
  }

  /// ตำแหน่งไฟล์ data.txt ในอุปกรณ์ / Resolve data.txt path inside device storage
  Future<File> get _dataFile async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File('${dir.path}/data.txt');
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('[]');
    }
    return file;
  }

  /// โหลดรายชื่อติวเตอร์จากไฟล์ / Load tutors from JSON file
  Future<void> _loadTutors() async {
    _isLoading = true;
    notifyListeners();
    try {
      final File file = await _dataFile;
      final String contents = await file.readAsString();
      final List<dynamic> data = jsonDecode(contents) as List<dynamic>;
      _tutors
        ..clear()
        ..addAll(
          data
              .map<Tutor?>(
                (dynamic item) {
                  if (item is Map<String, dynamic>) {
                    return Tutor.fromJson(item);
                  }
                  if (item is Map) {
                    return Tutor.fromJson(
                      item.map(
                        (dynamic key, dynamic value) => MapEntry(
                          key.toString(),
                          value,
                        ),
                      ),
                    );
                  }
                  return null;
                },
              )
              .whereType<Tutor>(),
        );
    } catch (e) {
      debugPrint('Failed to load tutors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// บันทึกรายชื่อติวเตอร์ลงไฟล์ / Persist tutors into JSON file
  Future<void> _saveTutors() async {
    try {
      final File file = await _dataFile;
      final String jsonArray = jsonEncode(
        _tutors.map((Tutor tutor) => tutor.toJson()).toList(),
      );
      await file.writeAsString(jsonArray);
    } catch (e) {
      debugPrint('Failed to save tutors: $e');
    }
  }

  /// สมัครสมาชิกติวเตอร์ / Register new tutor
  Future<String?> registerTutor({
    required String name,
    required String email,
    required String password,
  }) async {
    final bool alreadyExists =
        _tutors.any((Tutor tutor) => tutor.email.toLowerCase() == email.toLowerCase());
    if (alreadyExists) {
      return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
    }
    final Tutor tutor = Tutor(name: name, email: email, password: password);
    _tutors.add(tutor);
    await _saveTutors();
    notifyListeners();
    return null;
  }

  /// ล็อกอินสำหรับติวเตอร์ / Tutor login method
  Future<String?> loginTutor({
    required String email,
    required String password,
  }) async {
    try {
      if (_isLoading) {
        await _loadTutors();
      }
      final Tutor match = _tutors.firstWhere(
        (Tutor tutor) =>
            tutor.email.toLowerCase() == email.toLowerCase() && tutor.password == password,
        orElse: () => const Tutor(name: '', email: '', password: ''),
      );
      if (match.email.isEmpty) {
        return 'ไม่พบผู้ใช้ / Invalid email or password';
      }
      _currentTutor = match;
      _isAdminLoggedIn = false;
      notifyListeners();
      return null;
    } catch (e) {
      return 'เกิดข้อผิดพลาด ${e.toString()} / Unexpected error';
    }
  }

  /// ล็อกอินสำหรับแอดมิน / Admin login method
  Future<String?> loginAdmin({
    required String email,
    required String password,
  }) async {
    if (email == _adminEmail && password == _adminPassword) {
      _isAdminLoggedIn = true;
      _currentTutor = null;
      notifyListeners();
      return null;
    }
    return 'ข้อมูลไม่ถูกต้อง / Invalid admin credentials';
  }

  /// ออกจากระบบทั้งหมด / Logout for both tutor and admin
  void logout() {
    _currentTutor = null;
    _isAdminLoggedIn = false;
    notifyListeners();
  }
}
