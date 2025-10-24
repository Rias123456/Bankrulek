import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../services/tutor_service.dart';
import '../widgets/primary_button.dart';
import '../utils/session.dart';

class RegisterTutorScreen extends StatefulWidget {
  const RegisterTutorScreen({super.key});

  @override
  State<RegisterTutorScreen> createState() => _RegisterTutorScreenState();
}

class _RegisterTutorScreenState extends State<RegisterTutorScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _profileImageBase64;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
final TextEditingController _firstNameController = TextEditingController();
final TextEditingController _lastNameController = TextEditingController();
final TextEditingController _currentActivityController = TextEditingController();
final TextEditingController _travelDurationController = TextEditingController();
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSubmitting = true);

  try {
    // TODO: ใส่โค้ดสมัคร Firebase หรือ Firestore ตรงนี้
    // ตัวอย่างหลังสมัครเสร็จ:
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/tutor-login');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สมัครสำเร็จ!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}


  bool _isSubmitting = false;

final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
final TextEditingController _nicknameController = TextEditingController();
final TextEditingController _phoneController = TextEditingController();
final TextEditingController _lineIdController = TextEditingController();

Uint8List? _profileImageBytes;

bool loading = false;


@override
void dispose() {
  _emailController.dispose();
  _passwordController.dispose();
  _nicknameController.dispose();
  _phoneController.dispose();
  _lineIdController.dispose();
  super.dispose();
}

  Future<void> _pickImage() async {
  final file = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 1200,
  );
  if (file == null) return;

  final bytes = await file.readAsBytes();
  setState(() {
    _profileImageBase64 = base64Encode(bytes);
  });
}


 Future<void> _handleRegister() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isSubmitting = true);
  UserCredential? credential;
  
  try {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    // สร้างบัญชีใน Firebase Auth
    credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    final User? user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'ไม่สามารถสร้างบัญชีได้',
      );
    }

    final String tutorId = user.uid;
    String? photoUrl;
    
    // อัปโหลดรูปถ้ามี
    if (_profileImageBytes != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('tutors/$tutorId/profile.jpg');
        await storageRef.putData(_profileImageBytes!);
        photoUrl = await storageRef.getDownloadURL();
      } catch (e) {
        print('Error uploading image: $e');
      }
    }

    // บันทึกข้อมูลใน Firestore
    await FirebaseFirestore.instance
        .collection('tutors')
        .doc(tutorId)
        .set({
      'nickname': _nicknameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'lineId': _lineIdController.text.trim(),
      'email': email,
      'password': password,
      'currentStatus': 'เป็นครูอยู่',
      'travelTime': '',
      'subjects': <String>[],
      'schedule': <Map<String, dynamic>>[],
      'scheduleSerialized': '',
      'photoUrl': photoUrl,
      'profileImageBase64': _profileImageBase64,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // บันทึก session
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tutorId', tutorId);

    if (!mounted) return;
    
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login-success',
      (Route<dynamic> route) => false,
    );
    
  } on FirebaseAuthException catch (error) {
    // ถ้าสร้างบัญชีไม่สำเร็จ ให้ลบ user ที่สร้างไว้ (ถ้ามี)
    if (credential?.user != null) {
      try {
        await credential!.user!.delete();
      } catch (_) {}
    }
    
    if (!mounted) return;
    
    String message;
    switch (error.code) {
      case 'email-already-in-use':
        message = 'อีเมลนี้ถูกใช้แล้ว';
        break;
      case 'invalid-email':
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
        break;
      case 'weak-password':
        message = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
        break;
      default:
        message = error.message ?? 'ไม่สามารถสมัครสมาชิกได้';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    
  } catch (error) {
    // ถ้ามี error อื่นๆ
    if (credential?.user != null) {
      try {
        await credential!.user!.delete();
      } catch (_) {}
    }
    
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
      appBar: AppBar(title: const Text('สมัครติวเตอร์')),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: loading,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // รูปโปรไฟล์
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: (_profileImageBase64 == null)
                          ? null
                          : MemoryImage(base64Decode(_profileImageBase64!)),
                      child: _profileImageBase64 == null
                          ? const Icon(Icons.add_a_photo_outlined)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // อีเมล/รหัสผ่าน
                  TextFormField(
  controller: _emailController,
  decoration: const InputDecoration(labelText: 'อีเมล'),
  keyboardType: TextInputType.emailAddress,
  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกอีเมล' : null,
),

                 TextFormField(
  controller: _passwordController,
  decoration: const InputDecoration(labelText: 'รหัสผ่าน'),
  obscureText: true,
  validator: (v) => (v == null || v.length < 6) ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
),

                  const SizedBox(height: 12),

                  // ข้อมูลส่วนตัวหลัก
                  // ข้อมูลส่วนตัวหลัก
TextFormField(
  controller: _firstNameController,
  decoration: const InputDecoration(labelText: 'ชื่อจริง'),
  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อจริง' : null,
),
const SizedBox(height: 12),
TextFormField(
  controller: _lastNameController,
  decoration: const InputDecoration(labelText: 'นามสกุล'),
),
const SizedBox(height: 12),
TextFormField(
  controller: _nicknameController,
  decoration: const InputDecoration(labelText: 'ชื่อเล่น'),
  validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อเล่น' : null,
),
const SizedBox(height: 12),
TextFormField(
  controller: _phoneController,
  decoration: const InputDecoration(labelText: 'เบอร์โทรศัพท์'),
  keyboardType: TextInputType.phone,
),
const SizedBox(height: 12),
TextFormField(
  controller: _lineIdController,
  decoration: const InputDecoration(labelText: 'LINE ID'),
),
const SizedBox(height: 12),
TextFormField(
  controller: _currentActivityController,
  decoration: const InputDecoration(labelText: 'สิ่งที่กำลังทำอยู่'),
  minLines: 1,
  maxLines: 3,
),
const SizedBox(height: 12),
TextFormField(
  controller: _travelDurationController,
  decoration: const InputDecoration(labelText: 'ระยะเวลาเดินทาง (เช่น 30 นาที)'),
),
const SizedBox(height: 16),

                  // ปุ่มสมัคร
                 SizedBox(
  width: double.infinity,
  child: PrimaryButton(
    label: _isSubmitting ? 'กำลังสมัคร...' : 'สมัครติวเตอร์',
    onPressed: _isSubmitting ? null : _submit,
  ),
),
const SizedBox(height: 8),
TextButton(
  onPressed: _isSubmitting ? null : () => Navigator.pushReplacementNamed(context, '/tutor-login'),
  child: const Text('มีบัญชีแล้ว? ไปหน้าเข้าสู่ระบบ'),
),
], // ✅ ปิด children
), // ✅ ปิด Column หรือ Padding หรือ SingleChildScrollView

            ),
          ),
        ),
      ),
    );
  }
}
