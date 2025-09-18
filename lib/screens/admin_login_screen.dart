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
  /// key สำหรับฟอร์ม / Form key for admin login
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// controller ชื่อผู้ใช้ / Admin username controller
  final TextEditingController _usernameController = TextEditingController();

  /// controller รหัสผ่าน / Admin password controller
  final TextEditingController _passwordController = TextEditingController();

  /// สถานะกำลังล็อกอิน / Loading indicator state
  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ประมวลผลการล็อกอิน / Handle admin login action
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
        title: 'ล็อกอินแอดมินสำเร็จ / Admin login successful',
        message:
            'คุณสามารถเปิดแดชบอร์ดสำหรับจัดการข้อมูลได้ทันที / You can open the admin dashboard right away.',
        actionLabel: 'เปิดแดชบอร์ดแอดมิน / Open admin dashboard',
        actionRoute: '/admin-dashboard',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ล็อกอินแอดมิน / Admin Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อผู้ใช้ / Username',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกชื่อผู้ใช้ / Please enter username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน / Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน / Please enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isSubmitting
                    ? 'กำลังเข้าสู่ระบบ... / Signing in...'
                    : 'เข้าสู่ระบบ / Sign in',
                onPressed: _isSubmitting ? null : _handleLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
