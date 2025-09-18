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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ล็อกอินแอดมิน / Admin Login'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // โลโก้
                    Image.asset(
                      'assets/images/logo.png',
                      height: 100,
                    ),
                    const SizedBox(height: 24),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อผู้ใช้ / Username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกชื่อผู้ใช้ / Please enter username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน / Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกรหัสผ่าน / Please enter password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login button
                    PrimaryButton(
                      label: _isSubmitting
                          ? 'กำลังเข้าสู่ระบบ... / Signing in...'
                          : 'เข้าสู่ระบบ / Sign in',
                      onPressed: _isSubmitting ? null : _handleLogin,
                    ),

                    if (_isSubmitting) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
