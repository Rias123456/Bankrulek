import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';

/// หน้าสำหรับสมัครติวเตอร์ใหม่ / Tutor registration screen
class RegisterTutorScreen extends StatefulWidget {
  const RegisterTutorScreen({super.key});

  @override
  State<RegisterTutorScreen> createState() => _RegisterTutorScreenState();
}

class _RegisterTutorScreenState extends State<RegisterTutorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _lineIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _lineIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final authProvider = context.read<AuthProvider>();
    final int? age = int.tryParse(_ageController.text.trim());

    if (age == null) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รูปแบบอายุไม่ถูกต้อง / Invalid age format')),
      );
      return;
    }

    final String? error = await authProvider.registerTutor(
      name: _nameController.text.trim(),
      nickname: _nicknameController.text.trim(),
      age: age,
      lineId: _lineIdController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สมัครสำเร็จ / Registration completed')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครติวเตอร์ / Register Tutor'),
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

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อ-สกุล / Full name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'กรุณากรอกชื่อ / Please enter name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Nickname
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อเล่น / Nickname',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'กรุณากรอกชื่อเล่น / Please enter nickname' : null,
                    ),
                    const SizedBox(height: 16),

                    // Age
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'อายุ / Age',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณากรอกอายุ / Please enter age';
                        }
                        final int? age = int.tryParse(value);
                        if (age == null || age <= 0) {
                          return 'กรอกอายุเป็นตัวเลขมากกว่า 0 / Age must be positive';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Line ID
                    TextFormField(
                      controller: _lineIdController,
                      decoration: const InputDecoration(
                        labelText: 'ไอดีไลน์ / Line ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.chat),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'กรุณากรอกไอดีไลน์ / Please enter Line ID' : null,
                    ),
                    const SizedBox(height: 16),

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
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
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

                    // Register button
                    PrimaryButton(
                      label: _isSubmitting ? 'กำลังบันทึก... / Saving...' : 'สมัครสมาชิก / Register',
                      onPressed: _isSubmitting ? null : _handleRegister,
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
