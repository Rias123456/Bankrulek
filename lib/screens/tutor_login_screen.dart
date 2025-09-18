import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import 'login_success_screen.dart';

/// หน้าล็อกอินสำหรับติวเตอร์ / Tutor login screen
class TutorLoginScreen extends StatefulWidget {
  const TutorLoginScreen({super.key});

  @override
  State<TutorLoginScreen> createState() => _TutorLoginScreenState();
}

class _TutorLoginScreenState extends State<TutorLoginScreen> {
  /// key สำหรับจัดการฟอร์ม / Form key for validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// controller สำหรับอีเมล / Controller for email field
  final TextEditingController _emailController = TextEditingController();

  /// controller สำหรับรหัสผ่าน / Controller for password field
  final TextEditingController _passwordController = TextEditingController();

  /// สถานะกำลังส่งคำขอ / Submission loading state
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ฟังก์ชันเมื่อกดปุ่มล็อกอิน / Handle login action
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? error = await authProvider.loginTutor(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    Navigator.pushReplacementNamed(
      context,
      '/login-success',
      arguments: const LoginSuccessArgs(
        title: 'ล็อกอินสำเร็จ / Login successful',
        message: 'ยินดีต้อนรับกลับ! คุณสามารถกลับหน้าหลักได้จากปุ่มด้านล่าง / Welcome back! Use the button below to return home.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ล็อกอินติวเตอร์ / Tutor Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล / Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกอีเมล / Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง / Invalid email format';
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
                  if (value.length < 6) {
                    return 'อย่างน้อย 6 ตัวอักษร / Minimum 6 characters';
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
