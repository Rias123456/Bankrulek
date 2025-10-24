import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/tutor_service.dart';
import '../utils/session.dart';
import '../widgets/primary_button.dart';
import 'login_success_screen.dart';

/// หน้าล็อกอินสำหรับติวเตอร์
class TutorLoginScreen extends StatefulWidget {
  const TutorLoginScreen({super.key});

  @override
  State<TutorLoginScreen> createState() => _TutorLoginScreenState();
}

class _TutorLoginScreenState extends State<TutorLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TutorService _tutorService = TutorService();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String tutorId = await _tutorService.login(
        email: email,
        password: password,
      );
      await SessionHelper.saveTutorId(tutorId);

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/login-success',
        arguments: const LoginSuccessArgs(
          title: 'ล็อกอินสำเร็จ',
          message: 'ยินดีต้อนรับกลับ! คุณสามารถกลับหน้าหลักได้จากปุ่มด้านล่าง',
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      String message;
      switch (error.code) {
        case 'user-not-found':
          message = 'ไม่พบบัญชีผู้ใช้';
          break;
        case 'wrong-password':
          message = 'รหัสผ่านไม่ถูกต้อง';
          break;
        case 'invalid-email':
          message = 'รูปแบบอีเมลไม่ถูกต้อง';
          break;
        default:
          message = error.message ?? 'ไม่สามารถเข้าสู่ระบบได้';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1), // พื้นหลังสีชมพูอ่อน
      appBar: AppBar(
        title: const Text('ล็อกอินติวเตอร์'),
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // โลโก้ด้านบน
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: const AssetImage('assets/images/logo.png'),
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 40),

              // ช่องกรอกอีเมล
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  prefixIcon: const Icon(Icons.email),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกอีเมล';
                  }
                  if (!value.contains('@')) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ช่องกรอกรหัสผ่าน
              TextFormField(
                controller: _passwordController,
                obscureText: false,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน';
                  }
                  if (value.length < 6) {
                    return 'อย่างน้อย 6 ตัวอักษร';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ปุ่มล็อกอิน
              PrimaryButton(
                label: _isSubmitting ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                onPressed: _isSubmitting ? null : _handleLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
