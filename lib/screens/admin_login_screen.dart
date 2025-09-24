import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import 'login_success_screen.dart';

/// หน้าล็อกอินสำหรับผู้ดูแลระบบ / Admin login screen
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? error = await authProvider.loginAdmin(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/login-success',
      arguments: const LoginSuccessArgs(
        title: 'ล็อกอินแอดมินสำเร็จ',
        message: 'คุณสามารถเปิดแดชบอร์ดสำหรับจัดการข้อมูลได้ทันที',
        actionLabel: 'เปิดแดชบอร์ดแอดมิน ',
        actionRoute: '/admin-dashboard',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1), // พื้นหลังชมพูอ่อน
      appBar: AppBar(
        title: const Text('ล็อกอินแอดมิน'),
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // เปลี่ยนเป็น center
            children: [
              // ช่องกรอกชื่อผู้ใช้
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้',
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกชื่อผู้ใช้';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ช่องกรอกรหัสผ่าน (ไม่ซ่อน)
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: false, // ✅ แก้ไม่ซ่อนรหัสผ่าน
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ปุ่มล็อกอิน (ทำให้กรอบสั้นลง)
              SizedBox(
                width: 200, // ✅ กำหนดความกว้างเอง
                child: PrimaryButton(
                  label: _isSubmitting
                      ? 'กำลังเข้าสู่ระบบ...'
                      : 'เข้าสู่ระบบ',
                  onPressed: _isSubmitting ? null : _handleLogin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
