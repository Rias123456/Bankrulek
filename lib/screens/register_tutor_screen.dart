import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/primary_button.dart';

/// หน้าสำหรับสมัครติวเตอร์ใหม่
class RegisterTutorScreen extends StatefulWidget {
  const RegisterTutorScreen({super.key});

  @override
  State<RegisterTutorScreen> createState() => _RegisterTutorScreenState();
}

class _RegisterTutorScreenState extends State<RegisterTutorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _lineIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Uint8List? _profileImageBytes;
  String? _profileImageBase64;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final Uint8List bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
        _profileImageBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเลือกรูปได้')),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final String email = _emailController.text.trim();

      final QuerySnapshot<Map<String, dynamic>> existing = await firestore
          .collection('tutors')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อีเมลนี้ถูกใช้แล้ว')),
        );
        return;
      }

      String? photoUrl;
      if (_profileImageBytes != null) {
        final String fileName =
            'tutor_profiles/${DateTime.now().millisecondsSinceEpoch}_$email.jpg';
        final Reference ref = FirebaseStorage.instance.ref(fileName);
        final TaskSnapshot snapshot = await ref.putData(_profileImageBytes!);
        photoUrl = await snapshot.ref.getDownloadURL();
      }

      final DocumentReference<Map<String, dynamic>> docRef =
          await firestore.collection('tutors').add(<String, dynamic>{
        'fullName': '',
        'nickname': _nicknameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'lineId': _lineIdController.text.trim(),
        'email': email,
        'password': _passwordController.text.trim(),
        'photoUrl': photoUrl,
        'currentStatus': '',
        'travelTime': '',
        'subjects': <String>[],
        'schedule': <Map<String, dynamic>>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('tutorId', docRef.id);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login-success',
        (Route<dynamic> route) => false,
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'เกิดข้อผิดพลาด กรุณาลองอีกครั้ง')),
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
        title: const Text('สมัครติวเตอร์'),
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
              // โปรไฟล์
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isSubmitting ? null : _pickProfileImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: _profileImageBytes != null
                            ? MemoryImage(_profileImageBytes!)
                            : null,
                        child: _profileImageBytes == null
                            ? const Icon(Icons.person_add_alt_1,
                                size: 50, color: Colors.grey)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _pickProfileImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('เลือกรูปโปรไฟล์'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ฟอร์มกรอกข้อมูล
              _buildTextField(
                controller: _nicknameController,
                label: 'ชื่อเล่น',
                icon: Icons.person,
                validator: (value) =>
                    value == null || value.isEmpty ? 'กรุณากรอกชื่อเล่น' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'เบอร์โทรศัพท์',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _lineIdController,
                label: 'ไอดีไลน์',
                icon: Icons.message,
                validator: (value) =>
                    value == null || value.isEmpty ? 'กรุณากรอกไอดีไลน์' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'อีเมล',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณากรอกอีเมล';
                  if (!value.contains('@')) return 'รูปแบบอีเมลไม่ถูกต้อง';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ช่องรหัสผ่าน (ไม่ซ่อน)
              _buildTextField(
                controller: _passwordController,
                label: 'รหัสผ่าน',
                icon: Icons.lock,
                obscureText: false, // ✅ ไม่ซ่อน
                validator: (value) {
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

              // ปุ่มสมัคร (กรอบสั้นลง)
              Center(
                child: SizedBox(
                  width: 200,
                  child: PrimaryButton(
                    label: _isSubmitting ? 'กำลังบันทึก...' : 'สมัครสมาชิก',
                    onPressed: _isSubmitting ? null : _handleRegister,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ฟังก์ชันสร้าง TextField พร้อมตกแต่ง
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
}
