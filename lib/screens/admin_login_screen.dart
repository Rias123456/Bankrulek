import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';

/// หน้าล็อกอินสำหรับผู้ดูแลระบบ / Admin login screen
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  /// key สำหรับฟอร์ม / Form key for admin login
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// controller อีเมล / Admin email controller
  final TextEditingController _emailController = TextEditingController();

  /// controller รหัสผ่าน / Admin password controller
  final TextEditingController _passwordController = TextEditingController();

  /// สถานะกำลังล็อกอิน / Loading indicator state
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
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
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pushReplacementNamed(context, '/admin-dashboard');
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'อีเมล / Email',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกอีเมล / Please enter email';
                  }
                  if (!value.contains('@')) {
                    return 'รูปแบบอีเมลไม่ถูกต้อง / Invalid email';
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
