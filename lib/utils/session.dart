import 'package:shared_preferences/shared_preferences.dart';

/// ตัวช่วยจัดการ session ของติวเตอร์ด้วย SharedPreferences
class SessionHelper {
  SessionHelper._();

  static const String _tutorIdKey = 'tutorId';

  /// บันทึก tutorId ลง SharedPreferences เพื่อใช้สำหรับ Auto-login
  static Future<void> saveTutorId(String tutorId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tutorIdKey, tutorId);
  }

  /// คืนค่า tutorId ที่เคยบันทึกไว้ ถ้าไม่มีจะได้ค่า null
  static Future<String?> getTutorId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? tutorId = prefs.getString(_tutorIdKey);
    if (tutorId == null || tutorId.isEmpty) {
      return null;
    }
    return tutorId;
  }

  /// ลบ tutorId ออกจาก SharedPreferences
  static Future<void> clearTutorId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tutorIdKey);
  }
}
