import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// คลาสข้อมูลสำหรับเก็บรายละเอียดของติวเตอร์ / Data model for tutors
class Tutor {
  /// ชื่อเต็มของติวเตอร์ / Tutor full name
  final String name;

  /// ชื่อเล่น / Nickname
  final String nickname;

  /// อายุ / Age
  final int age;

  /// ไอดีไลน์ / Line ID
  final String lineId;

  /// อีเมลสำหรับล็อกอิน / Login email
  final String email;

  /// รหัสผ่านแบบ plaintext (ตัวอย่างเท่านั้น) / Plaintext password (for demo only)
  final String password;

  const Tutor({
    required this.name,
    required this.nickname,
    required this.age,
    required this.lineId,
    required this.email,
    required this.password,
  });

  /// แปลงเป็นข้อความบันทึก / Convert data into a readable storage line
  String toStorageLine() {
    String sanitize(String value) => value.replaceAll('\n', ' ').replaceAll('|', '/');
    return 'ชื่อจริง: ${sanitize(name)} | ชื่อเล่น: ${sanitize(nickname)} | อายุ: $age | '
        'ไอดีไลน์: ${sanitize(lineId)} | อีเมล: ${sanitize(email)} | รหัสผ่าน: ${sanitize(password)}';
  }

  /// สร้าง Tutor จากบรรทัดข้อความ / Create a Tutor from a storage line
  static Tutor? fromStorageLine(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final List<String> parts =
        trimmed.split('|').map((String part) => part.trim()).where((String part) => part.isNotEmpty).toList();
    if (parts.length < 6) {
      return null;
    }

    String? findValue(String label) {
      try {
        final String match =
            parts.firstWhere((String part) => part.startsWith('$label:'), orElse: () => '');
        if (match.isEmpty) {
          return null;
        }
        final int colonIndex = match.indexOf(':');
        if (colonIndex == -1) {
          return null;
        }
        return match.substring(colonIndex + 1).trim();
      } catch (_) {
        return null;
      }
    }

    final String? name = findValue('ชื่อจริง');
    final String? nickname = findValue('ชื่อเล่น');
    final String? ageText = findValue('อายุ');
    final String? lineId = findValue('ไอดีไลน์');
    final String? email = findValue('อีเมล');
    final String? password = findValue('รหัสผ่าน');
    if (name == null || nickname == null || ageText == null || lineId == null || email == null || password == null) {
      return null;
    }
    final int? age = int.tryParse(ageText);
    if (age == null) {
      return null;
    }
    return Tutor(
      name: name,
      nickname: nickname,
      age: age,
      lineId: lineId,
      email: email,
      password: password,
    );
  }
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
  static const String _adminUsername = 'admin1234';
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
      await file.writeAsString(_generateFileContent(_tutors, file.path));
    }
    return file;
  }

  /// โหลดรายชื่อติวเตอร์จากไฟล์ / Load tutors from text file
  Future<void> _loadTutors() async {
    _isLoading = true;
    notifyListeners();
    try {
      final File file = await _dataFile;
      final List<String> lines = await file.readAsLines();
      _tutors
        ..clear()
        ..addAll(
          lines
              .map((String line) => line.trim())
              .where((String line) => line.isNotEmpty && !line.startsWith('#'))
              .map<Tutor?>((String line) => Tutor.fromStorageLine(line))
              .whereType<Tutor>(),
        );
    } catch (e) {
      debugPrint('Failed to load tutors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// บันทึกรายชื่อติวเตอร์ลงไฟล์ / Persist tutors into text file
  Future<void> _saveTutors() async {
    try {
      final File file = await _dataFile;
      final String content = _generateFileContent(_tutors, file.path);
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('Failed to save tutors: $e');
    }
  }

  /// สร้างข้อความสำหรับบันทึกไฟล์ / Build file content with header instructions
  String _generateFileContent(List<Tutor> tutors, String filePath) {
    final String normalizedPath = filePath.replaceAll('\\', '/');
    final StringBuffer buffer = StringBuffer()
      ..writeln('# วิธีดูข้อมูลที่จัดเก็บไว้: เปิดไฟล์นี้ด้วยแอปจัดการไฟล์หรือเทอร์มินัล')
      ..writeln('# ที่อยู่ไฟล์: $normalizedPath')
      ..writeln('# ตัวอย่างคำสั่ง: cat "$normalizedPath"')
      ..writeln();
    for (final Tutor tutor in tutors) {
      buffer.writeln(tutor.toStorageLine());
    }
    return buffer.toString();
  }

  /// สมัครสมาชิกติวเตอร์ / Register new tutor
  Future<String?> registerTutor({
    required String name,
    required String nickname,
    required int age,
    required String lineId,
    required String email,
    required String password,
  }) async {
    final bool alreadyExists =
        _tutors.any((Tutor tutor) => tutor.email.toLowerCase() == email.toLowerCase());
    if (alreadyExists) {
      return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
    }
    final Tutor tutor = Tutor(
      name: name,
      nickname: nickname,
      age: age,
      lineId: lineId,
      email: email,
      password: password,
    );
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
      Tutor? match;
      try {
        match = _tutors.firstWhere(
          (Tutor tutor) =>
              tutor.email.toLowerCase() == email.toLowerCase() && tutor.password == password,
        );
      } on StateError {
        match = null;
      }
      if (match == null) {
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
    required String username,
    required String password,
  }) async {
    if (username == _adminUsername && password == _adminPassword) {
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
