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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true; // ซ่อนรหัสผ่านเริ่มต้น

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
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
        message:
            'ยินดีต้อนรับกลับ! คุณสามารถกลับหน้าหลักได้จากปุ่มด้านล่าง / Welcome back! Use the button below to return home.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ล็อกอินติวเตอร์ / Tutor Login'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
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

                    // Email
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล / Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
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
                        if (value.length < 6) {
                          return 'อย่างน้อย 6 ตัวอักษร / Minimum 6 characters';
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
