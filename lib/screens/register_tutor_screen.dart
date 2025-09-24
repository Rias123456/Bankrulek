import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  /// controller ชื่อเล่น / Controller for tutor nickname
  final TextEditingController _nicknameController = TextEditingController();

  /// controller ชื่อจริง / Controller for tutor first name
  final TextEditingController _firstNameController = TextEditingController();

  /// controller นามสกุล / Controller for tutor last name
  final TextEditingController _lastNameController = TextEditingController();

  /// controller อายุ / Controller for tutor age
  final TextEditingController _ageController = TextEditingController();

  /// controller เบอร์โทรศัพท์ / Controller for tutor phone number
  final TextEditingController _phoneController = TextEditingController();

  /// controller ไอดีไลน์ / Controller for tutor Line ID
  final TextEditingController _lineIdController = TextEditingController();

  /// controller อีเมล / Controller for tutor email
  final TextEditingController _emailController = TextEditingController();

  /// controller รหัสผ่าน / Controller for tutor password
  final TextEditingController _passwordController = TextEditingController();

  /// ข้อมูลรูปโปรไฟล์ที่เลือก / Picked profile image bytes
  Uint8List? _profileImageBytes;

  /// รูปโปรไฟล์ที่เข้ารหัส Base64 / Base64 encoded profile image string
  String? _profileImageBase64;

  /// สถานะกำลังบันทึก / Flag to show saving progress
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ให้ผู้ใช้เลือกรูปโปรไฟล์ / Allow the user to pick a profile image
  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return;
      }
      final Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
        _profileImageBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเลือกรูปได้ / Unable to pick image: $e')),
      );
    }
  }

  /// จัดการขั้นตอนการสมัคร / Handle registration process
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? error = await authProvider.registerTutor(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      nickname: _nicknameController.text.trim(),
      age: _ageController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      lineId: _lineIdController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      profileImageBase64: _profileImageBase64,
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
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isSubmitting ? null : _pickProfileImage,
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          backgroundImage:
                              _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                          child: _profileImageBytes == null
                              ? Icon(
                                  Icons.person_add_alt_1,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _isSubmitting ? null : _pickProfileImage,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('เลือกรูปโปรไฟล์ / Choose profile image'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อจริง / First name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกชื่อจริง / Please enter first name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'นามสกุล / Last name (ไม่บังคับ)',
                    border: OutlineInputBorder(),
                  ),
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
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'เบอร์โทรศัพท์ / Phone number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกเบอร์โทร / Please enter phone number';
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
