import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';

/// ค่าพารามิเตอร์สำหรับหน้าสำเร็จการล็อกอิน
class LoginSuccessArgs {
  /// หัวข้อแสดงผล
  final String title;

  /// ข้อความอธิบาย
  final String message;

  /// ป้ายปุ่มหลัก
  final String? actionLabel;

  /// เส้นทางเมื่อกดปุ่มหลัก
  final String? actionRoute;

  const LoginSuccessArgs({
    this.title = 'ล็อกอินสำเร็จ',
    this.message = 'คุณเข้าสู่ระบบเรียบร้อยแล้ว',
    this.actionLabel,
    this.actionRoute,
  });
}

/// หน้าโปรไฟล์หลังล็อกอินของติวเตอร์
class LoginSuccessScreen extends StatefulWidget {
  const LoginSuccessScreen({super.key});

  @override
  State<LoginSuccessScreen> createState() => _LoginSuccessScreenState();
}

class _LoginSuccessScreenState extends State<LoginSuccessScreen> {
  static const Map<String, List<String>> _subjectLevels = <String, List<String>>{
    'คณิต': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'วิทย์': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'ไทย': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'อังกฤษ': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'สังคม': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
    'ฟิสิก': <String>['มัธยมปลาย'],
    'ชีวะ': <String>['มัธยมปลาย'],
    'เคมี': <String>['มัธยมปลาย'],
  };

  static final List<String> _orderedSubjectOptions = _subjectLevels.entries
      .expand(
        (MapEntry<String, List<String>> entry) =>
            entry.value.map((String level) => '${entry.key} ($level)'),
      )
      .toList(growable: false);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _lineIdController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _scheduleController = TextEditingController();

  String _selectedStatus = Tutor.defaultStatus;
  List<String> _selectedSubjects = <String>[];
  bool _isSaving = false;
  String? _lastSyncedSignature;

  @override
  void dispose() {
    _nicknameController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _emailController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  void _synchronizeControllers(Tutor tutor) {
    final String signature = _buildTutorSignature(tutor);
    if (_lastSyncedSignature == signature) {
      return;
    }
    _nicknameController.text = tutor.nickname;
    _phoneController.text = tutor.phoneNumber;
    _lineIdController.text = tutor.lineId;
    _emailController.text = tutor.email;
    _selectedStatus = tutor.status;
    _selectedSubjects = List<String>.from(tutor.subjects);
    _scheduleController.text = tutor.teachingSchedule ?? '';
    _lastSyncedSignature = signature;
  }

  String _buildTutorSignature(Tutor tutor) {
    final String subjectsSignature = tutor.subjects.join(',');
    final String scheduleSignature = tutor.teachingSchedule ?? '';
    return '${tutor.email}|${tutor.nickname}|${tutor.phoneNumber}|${tutor.lineId}|${tutor.status}|'
        '$subjectsSignature|$scheduleSignature';
  }

  ImageProvider<Object>? _buildProfileImage(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) {
      return null;
    }
    try {
      return MemoryImage(base64Decode(base64Data));
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final AuthProvider authProvider = context.read<AuthProvider>();
    final Tutor? currentTutor = authProvider.currentTutor;
    if (currentTutor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้สอนในระบบ')),
      );
      return;
    }
    setState(() => _isSaving = true);

    final Tutor updatedTutor = currentTutor.copyWith(
      nickname: _nicknameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      lineId: _lineIdController.text.trim(),
      email: _emailController.text.trim(),
      status: _selectedStatus,
      subjects: List<String>.from(_selectedSubjects),
      teachingSchedule: _scheduleController.text.trim().isEmpty
          ? null
          : _scheduleController.text.trim(),
    );

    final String? error = await authProvider.updateTutor(
      originalEmail: currentTutor.email,
      updatedTutor: updatedTutor,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    _lastSyncedSignature = _buildTutorSignature(updatedTutor);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
    );
  }

  void _handleLogout() {
    context.read<AuthProvider>().logout();
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _showSubjectPicker() async {
    final Set<String> tempSelected = Set<String>.from(_selectedSubjects);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'เลือกวิชาที่สอน',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: ListView.separated(
                      itemCount: _orderedSubjectOptions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final String option = _orderedSubjectOptions[index];
                        final bool isSelected = tempSelected.contains(option);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(option),
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value ?? false) {
                                tempSelected.add(option);
                              } else {
                                tempSelected.remove(option);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ยกเลิก'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedSubjects = _orderedSubjectOptions
                                  .where(tempSelected.contains)
                                  .toList();
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('ยืนยัน'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// ✅ แก้ไข Header ให้แสดงเฉพาะภาพ + ชื่อเล่น + ปุ่มแก้ไข
  Widget _buildHeaderCard(Tutor tutor) {
    final ImageProvider<Object>? imageProvider =
        _buildProfileImage(tutor.profileImageBase64);

    final String nicknameDisplay = _nicknameController.text.trim().isEmpty
        ? tutor.nickname
        : _nicknameController.text.trim();

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFFFF5F5),
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                InkWell(
                  onTap: () {
                    // TODO: เพิ่มฟังก์ชันเลือกรูป
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("กดเพื่อเปลี่ยนรูปโปรไฟล์")),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit,
                        size: 20, color: Colors.blueAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ครู$nicknameDisplay',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'ข้อมูลส่วนตัว',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nicknameController,
              label: 'ชื่อเล่น',
              icon: Icons.person,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                      ? 'กรุณากรอกชื่อเล่น'
                      : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'เบอร์โทรศัพท์',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                      ? 'กรุณากรอกเบอร์โทรศัพท์'
                      : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _lineIdController,
              label: 'ID LINE',
              icon: Icons.chat,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty
                      ? 'กรุณากรอก ID LINE'
                      : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'อีเมล (สำหรับเข้าสู่ระบบ)',
              icon: Icons.email,
              readOnly: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: _inputDecoration(label: 'สถานะปัจจุบัน', icon: Icons.flag),
              items: Tutor.statuses
                  .map((String status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (String? value) {
                if (value == null) return;
                setState(() => _selectedStatus = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'วิชาที่สอน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _showSubjectPicker,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'เพิ่มวิชาที่สอน',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedSubjects.isEmpty)
              Text(
                'ยังไม่ได้เลือกวิชา',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedSubjects
                    .map(
                      (String subject) => InputChip(
                        label: Text(subject),
                        onDeleted: () {
                          setState(() {
                            _selectedSubjects.remove(subject);
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'ตารางสอน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _scheduleController,
              minLines: 3,
              maxLines: 6,
              decoration: _inputDecoration(
                label: 'ระบุวันและเวลาที่สอนได้',
                icon: Icons.schedule,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 72, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'ไม่พบข้อมูลผู้สอน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'กรุณากลับไปหน้าหลักแล้วเข้าสู่ระบบอีกครั้ง',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: PrimaryButton(
                label: 'กลับหน้าหลัก',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (Route<dynamic> route) => false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('โปรไฟล์ติวเตอร์'),
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final Tutor? tutor = authProvider.currentTutor;
          if (tutor == null) {
            return _buildEmptyState(context);
          }

          _synchronizeControllers(tutor);

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeaderCard(tutor),
                  const SizedBox(height: 16),
                  _buildInformationCard(),
                  const SizedBox(height: 16),
                  _buildSubjectCard(),
                  const SizedBox(height: 16),
                  _buildScheduleCard(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: _isSaving ? 'กำลังบันทึก...' : 'บันทึก',
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isSaving ? null : _handleLogout,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('ออกจากระบบ'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
