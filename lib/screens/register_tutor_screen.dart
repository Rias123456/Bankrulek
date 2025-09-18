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
  /// key สำหรับฟอร์ม / Global key to manage the form
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// controller ชื่อ / Controller for tutor name
  final TextEditingController _nameController = TextEditingController();

  /// controller ชื่อเล่น / Controller for tutor nickname
  final TextEditingController _nicknameController = TextEditingController();

  /// controller อายุ / Controller for tutor age
  final TextEditingController _ageController = TextEditingController();

  /// controller ไอดีไลน์ / Controller for tutor Line ID
  final TextEditingController _lineIdController = TextEditingController();

  /// controller อีเมล / Controller for tutor email
  final TextEditingController _emailController = TextEditingController();

  /// controller รหัสผ่าน / Controller for tutor password
  final TextEditingController _passwordController = TextEditingController();

  /// สถานะกำลังบันทึก / Flag to show saving progress
  bool _isSubmitting = false;

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

  /// จัดการขั้นตอนการสมัคร / Handle registration process
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final AuthProvider authProvider = context.read<AuthProvider>();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครติวเตอร์ / Register Tutor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อ-สกุล / Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อ / Please enter name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อเล่น / Nickname',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อเล่น / Please enter nickname';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(
                    labelText: 'อายุ / Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
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
                TextFormField(
                  controller: _lineIdController,
                  decoration: const InputDecoration(
                    labelText: 'ไอดีไลน์ / Line ID',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกไอดีไลน์ / Please enter Line ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                      ? 'กำลังบันทึก... / Saving...'
                      : 'สมัครสมาชิก / Register',
                  onPressed: _isSubmitting ? null : _handleRegister,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
