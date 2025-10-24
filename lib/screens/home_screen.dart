import 'package:flutter/material.dart';

import '../utils/session.dart';

/// หน้าหลักของระบบ / Main entry screen for the portal
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCheckingAutoLogin = true;
  bool _hasAttemptedNavigation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoLogin());
  }

  Future<void> _checkAutoLogin() async {
    if (_hasAttemptedNavigation) {
      return;
    }
    _hasAttemptedNavigation = true;
    try {
      final String? tutorId = await SessionHelper.getTutorId();
      if (tutorId != null && tutorId.isNotEmpty) {
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(context, '/login-success');
        return;
      }
    } catch (_) {
      // Ignore errors and fall back to manual login flow.
    }
    if (!mounted) {
      return;
    }
    setState(() => _isCheckingAutoLogin = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAutoLogin) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE4E1),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      body: SafeArea(
        child: Stack(
          children: [
            // โลโก้ด้านบน
            Align(
              alignment: const Alignment(0, -0.9), // ค่า y = -1.0 คือบนสุด, 1.0 คือ ล่างสุด
              child: CircleAvatar(
                radius: 80,
                backgroundImage: const AssetImage('assets/images/logo.png'),
                backgroundColor: Colors.white,
              ),
            ),

            // ชื่อระบบ
            Align(
              alignment: const Alignment(0, -0.65),
              child: const Text(
                '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // ปุ่ม Admin Login
            Align(
              alignment: const Alignment(0, -0.2), // กำหนดตำแหน่งเอง (แก้ค่า y ได้)
              child: _buildStyledButton(
                context,
                label: 'Admin Login',
                icon: Icons.lock,
                onPressed: () => Navigator.pushNamed(context, '/admin-login'),
              ),
            ),

            // ปุ่ม ลงทะเบียนติวเตอร์
            Align(
              alignment: const Alignment(0, 0.0), // อยู่ตรงกลางจอ (y = 0)
              child: _buildStyledButton(
                context,
                label: 'ลงทะเบียนติวเตอร์',
                icon: Icons.person_add,
                onPressed: () => Navigator.pushNamed(context, '/register-tutor'),
              ),
            ),

            // ปุ่ม เข้าสู่ระบบติวเตอร์
            Align(
              alignment: const Alignment(0, 0.2), // อยู่ต่ำกว่า (แก้ y ได้)
              child: _buildStyledButton(
                context,
                label: 'เข้าสู่ระบบติวเตอร์',
                icon: Icons.login,
                onPressed: () => Navigator.pushNamed(context, '/tutor-login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ปุ่มสไตล์
  Widget _buildStyledButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 220,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.black87),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          minimumSize: const Size(220, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
