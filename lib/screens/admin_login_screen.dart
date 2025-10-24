import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/primary_button.dart';

const String _adminPassword = '******';

/// หน้าล็อกอินสำหรับผู้ดูแลระบบ / Admin login screen
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final String password = _passwordController.text.trim();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    setState(() => _isSubmitting = false);
    if (!mounted) {
      return;
    }
    if (password != _adminPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ข้อมูลไม่ถูกต้อง / Invalid admin credentials')),
      );
      return;
    }
    Navigator.pushReplacementNamed(context, '/admin-dashboard');
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
              // ช่องกรอกรหัสผ่าน
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  hintText: '',
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
                obscuringCharacter: '*',
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
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
