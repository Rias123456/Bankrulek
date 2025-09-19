import 'package:flutter/material.dart';


/// หน้าหลักของระบบ / Main entry screen for the portal
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1), // พื้นหลังสีชมพูอ่อน
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // โลโก้กลม
              CircleAvatar(
                radius: 60,
                backgroundImage: const AssetImage('assets/images/logo.png'),
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),

              // ชื่อระบบ
              const Text(
                'บ้านครูเล็ก',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),

              // ปุ่ม Admin Login
              _buildStyledButton(
                context,
                label: 'Admin Login',
                icon: Icons.lock,
                onPressed: () => Navigator.pushNamed(context, '/admin-login'),
              ),
              const SizedBox(height: 20),

              // ปุ่ม Register Tutor
              _buildStyledButton(
                context,
                label: 'ลงทะเบียนติวเตอร์',
                icon: Icons.person_add,
                onPressed: () =>
                    Navigator.pushNamed(context, '/register-tutor'),
              ),
              const SizedBox(height: 20),

              // ปุ่ม Tutor Login
              _buildStyledButton(
                context,
                label: 'เข้าสู่ระบบติวเตอร์',
                icon: Icons.login,
                onPressed: () => Navigator.pushNamed(context, '/tutor-login'),
              ),
            ],
          ),
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
      width: double.infinity,
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
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
      ),
    );
  }
}
