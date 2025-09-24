import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';

/// ค่าพารามิเตอร์สำหรับหน้าสำเร็จการล็อกอิน / Arguments for the login success screen
class LoginSuccessArgs {
  /// หัวข้อแสดงผล / Title to display
  final String title;

  /// ข้อความอธิบาย / Description message
  final String message;

  /// ป้ายปุ่มหลัก / Label for the primary action button
  final String? actionLabel;

  /// เส้นทางเมื่อกดปุ่มหลัก / Route to navigate for the primary action
  final String? actionRoute;

  const LoginSuccessArgs({
    this.title = 'ล็อกอินสำเร็จ / Login Successful',
    this.message = 'คุณเข้าสู่ระบบเรียบร้อยแล้ว / You have signed in successfully.',
    this.actionLabel,
    this.actionRoute,
  });
}

/// หน้าแสดงโปรไฟล์หลังล็อกอิน / Screen displayed after successful login
class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({super.key});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> {
  static const Map<String, List<String>> _subjectGradeMap = <String, List<String>>{
    'คณิต': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'วิทย์': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'ไทย': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'อังกฤษ': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'สังคม': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'ฟิสิก': <String>['มัธยมปลาย'],
    'ชีวะ': <String>['มัธยมปลาย'],
    'เคมี': <String>['มัธยมปลาย'],
  };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _lineIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _currentActivityController = TextEditingController();
  final TextEditingController _travelTimeController = TextEditingController();
  final TextEditingController _scheduleNotesController = TextEditingController();

  late final List<String> _subjectOptions;
  final List<String> _selectedSubjects = <String>[];
  Uint8List? _profileImageBytes;
  Tutor? _lastSyncedTutor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _subjectOptions = _subjectGradeMap.entries
        .expand(
          (MapEntry<String, List<String>> entry) =>
              entry.value.map((String level) => '${entry.key} - $level'),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _currentActivityController.dispose();
    _travelTimeController.dispose();
    _scheduleNotesController.dispose();
    super.dispose();
  }

  void _syncWithTutor(Tutor tutor) {
    if (identical(_lastSyncedTutor, tutor)) {
      return;
    }
    _lastSyncedTutor = tutor;
    _firstNameController.text = tutor.firstName;
    _lastNameController.text = tutor.lastName;
    _nicknameController.text = tutor.nickname;
    _ageController.text = tutor.age;
    _phoneController.text = tutor.phoneNumber;
    _lineIdController.text = tutor.lineId;
    _emailController.text = tutor.email;
    _passwordController.text = tutor.password;
    _currentActivityController.text = tutor.currentActivity;
    _travelTimeController.text = tutor.travelTime;
    _scheduleNotesController.text = tutor.scheduleNotes;
    _selectedSubjects
      ..clear()
      ..addAll(tutor.subjects);
    if (tutor.profileImageBase64 != null && tutor.profileImageBase64!.isNotEmpty) {
      try {
        _profileImageBytes = base64Decode(tutor.profileImageBase64!);
      } catch (_) {
        _profileImageBytes = null;
      }
    } else {
      _profileImageBytes = null;
    }
  }

  Future<void> _handleSave(AuthProvider authProvider, Tutor tutor) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    final Tutor updatedTutor = tutor.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      nickname: _nicknameController.text.trim(),
      age: _ageController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      lineId: _lineIdController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      currentActivity: _currentActivityController.text.trim(),
      travelTime: _travelTimeController.text.trim(),
      scheduleNotes: _scheduleNotesController.text.trim(),
      subjects: List<String>.from(_selectedSubjects),
    );
    final String? error = await authProvider.updateTutor(
      originalEmail: tutor.email,
      updatedTutor: updatedTutor,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกโปรไฟล์สำเร็จ / Profile updated')),
    );
  }

  void _handleLogout(AuthProvider authProvider) {
    authProvider.logout();
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(context, '/', (Route<dynamic> _) => false);
  }

  Future<void> _showSubjectPicker() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text('เลือกวิชาที่สอน / Choose a subject'),
              ),
              for (final String option in _subjectOptions)
                ListTile(
                  title: Text(option),
                  trailing: _selectedSubjects.contains(option)
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) {
      return;
    }
    if (_selectedSubjects.contains(selected)) {
      return;
    }
    setState(() => _selectedSubjects.add(selected));
  }

  void _removeSubject(String subject) {
    setState(() => _selectedSubjects.remove(subject));
  }

  Widget _buildAdminSuccess(BuildContext context, LoginSuccessArgs args) {
    final bool hasPrimaryAction = args.actionLabel != null &&
        args.actionRoute != null &&
        args.actionLabel!.isNotEmpty &&
        args.actionRoute!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(args.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 96,
            ),
            const SizedBox(height: 24),
            Text(
              args.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              args.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            if (hasPrimaryAction)
              PrimaryButton(
                label: args.actionLabel!,
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    args.actionRoute!,
                    (Route<dynamic> _) => false,
                  );
                },
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> _) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: const Text('กลับหน้าหลัก / Back to home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackSuccess(BuildContext context, LoginSuccessArgs args) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(args.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 96,
            ),
            const SizedBox(height: 24),
            Text(
              args.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'กลับหน้าหลัก / Back to home',
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> _) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider authProvider = context.watch<AuthProvider>();
    final Object? rawArgs = ModalRoute.of(context)?.settings.arguments;
    final LoginSuccessArgs args =
        rawArgs is LoginSuccessArgs ? rawArgs : const LoginSuccessArgs();

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (authProvider.isAdminLoggedIn) {
      return _buildAdminSuccess(context, args);
    }

    final Tutor? tutor = authProvider.currentTutor;
    if (tutor == null) {
      return _buildFallbackSuccess(context, args);
    }

    _syncWithTutor(tutor);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('โปรไฟล์ติวเตอร์ / Tutor Profile'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                      backgroundImage:
                          _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                      child: _profileImageBytes == null
                          ? Icon(
                              Icons.person,
                              size: 48,
                              color: theme.colorScheme.primary,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ครู${tutor.nickname}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (tutor.status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Chip(
                          label: Text('สถานะ: ${tutor.status}'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (args.message.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      args.message,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              TextFormField(
                controller: _firstNameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'ชื่อจริง / First name',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อจริง / Please enter first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'นามสกุล / Last name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nicknameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'ชื่อเล่น / Nickname',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกชื่อเล่น / Please enter nickname';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'อายุ / Age',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกอายุ / Please enter age';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lineIdController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'ID LINE',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกไอดีไลน์ / Please enter Line ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'เบอร์โทร / Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกเบอร์โทร / Please enter phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'อีเมล (สำหรับล็อกอิน) / Email',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
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
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่าน / Password',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกรหัสผ่าน / Please enter password';
                  }
                  if (value.length < 6) {
                    return 'อย่างน้อย 6 ตัวอักษร / Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentActivityController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'สิ่งที่กำลังทำในปัจจุบัน / Current activity',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _travelTimeController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'เวลาที่ใช้เดินทางมาสอน / Travel time',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _scheduleNotesController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'ตารางสอน / Teaching schedule',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'วิชาที่สอน / Subjects',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedSubjects.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('ยังไม่ได้เลือกวิชา / No subjects selected'),
                    ),
                  for (final String subject in _selectedSubjects)
                    InputChip(
                      label: Text(subject),
                      onDeleted: _isSaving ? null : () => _removeSubject(subject),
                    ),
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _showSubjectPicker,
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มวิชา / Add subject'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: _isSaving
                    ? 'กำลังบันทึก... / Saving...'
                    : 'บันทึกโปรไฟล์ / Save profile',
                onPressed: _isSaving ? null : () => _handleSave(authProvider, tutor),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isSaving ? null : () => _handleLogout(authProvider),
                child: const Text('ออกจากระบบ / Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
