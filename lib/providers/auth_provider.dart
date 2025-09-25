import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// คลาสข้อมูลสำหรับเก็บรายละเอียดของติวเตอร์ / Data model for tutors
class Tutor {
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

  /// ข้อมูลรูปโปรไฟล์แบบ Base64 / Base64-encoded profile image data
  final String? profileImageBase64;

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
    required this.nickname,
    required this.phoneNumber,
    required this.lineId,
    required this.email,
    required this.password,
    required this.status,
    required this.travelDuration,
    this.profileImageBase64,
    this.subjects = const <String>[],
    this.teachingSchedule,
  });

  /// แปลงเป็นข้อความบันทึก / Convert data into a readable storage line
  String toStorageLine() {
    String sanitize(String value) => value.replaceAll('\n', ' ').replaceAll('|', '/');
    final String imageSnippet =
        profileImageBase64 != null && profileImageBase64!.isNotEmpty ? sanitize(profileImageBase64!) : '';
    final String subjectsSnippet = subjects.isNotEmpty
        ? sanitize(subjects.join(', '))
        : '';
    final String scheduleSnippet =
        teachingSchedule != null && teachingSchedule!.isNotEmpty ? sanitize(teachingSchedule!) : '';
    final String statusSnippet = sanitize(status.isNotEmpty ? status : defaultStatus);
    final String travelSnippet = travelDuration.isNotEmpty ? sanitize(travelDuration) : '';
    return 'ชื่อเล่น: ${sanitize(nickname)} | เบอร์โทร: ${sanitize(phoneNumber)} | '
        'ไอดีไลน์: ${sanitize(lineId)} | อีเมล: ${sanitize(email)} | รหัสผ่าน: ${sanitize(password)} | '
        'สถานะ: $statusSnippet | ระยะเวลาเดินทาง: $travelSnippet | รูปโปรไฟล์: $imageSnippet | วิชาที่สอน: $subjectsSnippet | '
        'ตารางสอน: $scheduleSnippet';
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

    final String? nickname = findValue('ชื่อเล่น');
    final String? phoneNumber = findValue('เบอร์โทร') ?? findValue('เบอร์โทรศัพท์');
    final String? lineId = findValue('ไอดีไลน์');
    final String? email = findValue('อีเมล');
    final String? password = findValue('รหัสผ่าน');
    final String? rawStatus = findValue('สถานะ');
    final String? rawTravel = findValue('ระยะเวลาเดินทาง');
    String statusValue = rawStatus == null || rawStatus.trim().isEmpty
        ? defaultStatus
        : rawStatus.trim();
    String travelDurationValue = defaultTravelDuration;
    if (rawTravel != null && rawTravel.trim().isNotEmpty) {
      final String trimmedTravel = rawTravel.trim();
      if (statuses.contains(trimmedTravel) || trimmedTravel == defaultStatus) {
        statusValue = statusValue.isEmpty || statusValue == defaultStatus
            ? trimmedTravel
            : statusValue;
      } else {
        travelDurationValue = trimmedTravel;
      }
    }
    final String? profileImageBase64 = findValue('รูปโปรไฟล์');
    final String? subjectsValue = findValue('วิชาที่สอน');
    final List<String> subjects = subjectsValue == null || subjectsValue.trim().isEmpty
        ? <String>[]
        : subjectsValue
            .split(',')
            .map((String subject) => subject.trim())
            .where((String subject) => subject.isNotEmpty)
            .toList();
    final String? teachingScheduleValue = findValue('ตารางสอน');
    final String? teachingSchedule =
        teachingScheduleValue == null || teachingScheduleValue.trim().isEmpty ? null : teachingScheduleValue;

    if (nickname == null || lineId == null || email == null || password == null) {
      return null;
    }
    return Tutor(
      nickname: nickname,
      phoneNumber: phoneNumber ?? '',
      lineId: lineId,
      email: email,
      password: password,
      status: statusValue,
      travelDuration: travelDurationValue,
      profileImageBase64: profileImageBase64,
      subjects: subjects,
      teachingSchedule: teachingSchedule,
    );
  }

  /// สร้างอ็อบเจ็กต์ใหม่โดยคงค่าเดิม / Copy with new field values
  Tutor copyWith({
    String? nickname,
    String? phoneNumber,
    String? lineId,
    String? email,
    String? password,
    String? status,
    String? travelDuration,
    String? profileImageBase64,
    List<String>? subjects,
    String? teachingSchedule,
  }) {
    return Tutor(
      nickname: nickname ?? this.nickname,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lineId: lineId ?? this.lineId,
      email: email ?? this.email,
      password: password ?? this.password,
      status: status ?? this.status,
      travelDuration: travelDuration ?? this.travelDuration,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      subjects: subjects ?? this.subjects,
      teachingSchedule: teachingSchedule ?? this.teachingSchedule,
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
      ..writeln('# ฟอร์แมตข้อมูล: ชื่อเล่น | เบอร์โทร | ไอดีไลน์ | อีเมล | รหัสผ่าน | สถานะ | ระยะเวลาเดินทาง | รูปโปรไฟล์ (Base64) | วิชาที่สอน | ตารางสอน')
      ..writeln();
    for (final Tutor tutor in tutors) {
      buffer.writeln(tutor.toStorageLine());
    }
    return buffer.toString();
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
    final bool alreadyExists =
        _tutors.any((Tutor tutor) => tutor.email.toLowerCase() == email.toLowerCase());
    if (alreadyExists) {
      return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
    }
    final Tutor tutor = Tutor(
      nickname: nickname,
      phoneNumber: phoneNumber,
      lineId: lineId,
      email: email,
      password: password,
      status: Tutor.defaultStatus,
      travelDuration: Tutor.defaultTravelDuration,
      profileImageBase64: profileImageBase64,
      subjects: const <String>[],
      teachingSchedule: null,
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

  /// อัปเดตข้อมูลติวเตอร์ / Update tutor information
  Future<String?> updateTutor({
    required String originalEmail,
    required Tutor updatedTutor,
  }) async {
    final int index = _tutors.indexWhere(
      (Tutor tutor) => tutor.email.toLowerCase() == originalEmail.toLowerCase(),
    );
    if (index == -1) {
      return 'ไม่พบผู้ใช้ / Tutor not found';
    }
    final String newEmail = updatedTutor.email.trim();
    final bool isEmailChanged = newEmail.toLowerCase() != originalEmail.toLowerCase();
    if (isEmailChanged) {
      final bool emailExists = _tutors.any(
        (Tutor tutor) => tutor.email.toLowerCase() == newEmail.toLowerCase(),
      );
      if (emailExists) {
        return 'อีเมลนี้ถูกใช้แล้ว / Email already registered';
      }
    }
    _tutors[index] = updatedTutor;
    if (_currentTutor != null &&
        _currentTutor!.email.toLowerCase() == originalEmail.toLowerCase()) {
      _currentTutor = updatedTutor;
    }
    await _saveTutors();
    notifyListeners();
    return null;
  }

  /// ลบข้อมูลติวเตอร์ออกจากระบบ / Delete tutor from storage
  Future<bool> deleteTutor(String email) async {
    final int index = _tutors.indexWhere(
      (Tutor tutor) => tutor.email.toLowerCase() == email.toLowerCase(),
    );
    if (index == -1) {
      return false;
    }
    _tutors.removeAt(index);
    await _saveTutors();
    notifyListeners();
    return true;
  }
}
