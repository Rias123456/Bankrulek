import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// หน้าควบคุมสำหรับแอดมิน / Administrative dashboard screen
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<void> _showEditTutorDialog(Tutor tutor) async {
    final TextEditingController firstNameController = TextEditingController(text: tutor.firstName);
    final TextEditingController lastNameController = TextEditingController(text: tutor.lastName);
    final TextEditingController nicknameController = TextEditingController(text: tutor.nickname);
    final TextEditingController ageController = TextEditingController(text: tutor.age);
    final TextEditingController phoneController = TextEditingController(text: tutor.phoneNumber);
    final TextEditingController lineIdController = TextEditingController(text: tutor.lineId);
    final TextEditingController emailController = TextEditingController(text: tutor.email);
    final TextEditingController passwordController = TextEditingController(text: tutor.password);
    final TextEditingController currentActivityController =
        TextEditingController(text: tutor.currentActivity);
    final TextEditingController travelTimeController =
        TextEditingController(text: tutor.travelTime);
    final TextEditingController scheduleNotesController =
        TextEditingController(text: tutor.scheduleNotes);
    final TextEditingController subjectsController =
        TextEditingController(text: tutor.subjects.join(', '));
    String selectedStatus = tutor.status;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final List<String> statusOptions = List<String>.from(Tutor.statuses);
            if (!statusOptions.contains(selectedStatus)) {
              statusOptions.add(selectedStatus);
            }
            return AlertDialog(
              title: const Text('แก้ไขข้อมูลผู้ใช้ / Edit tutor'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อจริง / First name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'นามสกุล / Last name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อเล่น / Nickname',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ageController,
                      decoration: const InputDecoration(
                        labelText: 'อายุ / Age',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทร / Phone number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lineIdController,
                      decoration: const InputDecoration(
                        labelText: 'ไอดีไลน์ / Line ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล / Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน / Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: currentActivityController,
                      decoration: const InputDecoration(
                        labelText: 'สิ่งที่ทำในปัจจุบัน / Current activity',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: travelTimeController,
                      decoration: const InputDecoration(
                        labelText: 'เวลาเดินทาง / Travel time',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: scheduleNotesController,
                      decoration: const InputDecoration(
                        labelText: 'ตารางสอน / Schedule notes',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectsController,
                      decoration: const InputDecoration(
                        labelText: 'วิชาที่สอน (คั่นด้วย ,) / Subjects taught',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'สถานะ / Status',
                        border: OutlineInputBorder(),
                      ),
                      items: statusOptions
                          .map(
                            (String status) => DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setDialogState(() => selectedStatus = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('ยกเลิก / Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String firstName = firstNameController.text.trim();
                          final String lastName = lastNameController.text.trim();
                          final String nickname = nicknameController.text.trim();
                          final String age = ageController.text.trim();
                          final String phoneNumber = phoneController.text.trim();
                          final String lineId = lineIdController.text.trim();
                          final String email = emailController.text.trim();
                          final String password = passwordController.text.trim();
                          final String currentActivity = currentActivityController.text.trim();
                          final String travelTime = travelTimeController.text.trim();
                          final String scheduleNotes = scheduleNotesController.text.trim();
                          final List<String> subjects = subjectsController.text
                              .split(',')
                              .map((String value) => value.trim())
                              .where((String value) => value.isNotEmpty)
                              .toList();
                          if (firstName.isEmpty || nickname.isEmpty || phoneNumber.isEmpty || lineId.isEmpty || email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกข้อมูลให้ครบถ้วน / Please fill in all fields'),
                              ),
                            );
                            return;
                          }
                          if (!email.contains('@')) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('รูปแบบอีเมลไม่ถูกต้อง / Invalid email format'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final AuthProvider authProvider = this.context.read<AuthProvider>();
                          final Tutor updatedTutor = tutor.copyWith(
                            firstName: firstName,
                            lastName: lastName,
                            nickname: nickname,
                            age: age,
                            phoneNumber: phoneNumber,
                            lineId: lineId,
                            email: email,
                            password: password,
                            status: selectedStatus,
                            currentActivity: currentActivity,
                            travelTime: travelTime,
                            scheduleNotes: scheduleNotes,
                            subjects: subjects,
                          );
                          final String? error = await authProvider.updateTutor(
                            originalEmail: tutor.email,
                            updatedTutor: updatedTutor,
                          );
                          if (!mounted) {
                            return;
                          }
                          if (error != null) {
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text(error)),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ / Tutor updated')),
                          );
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('บันทึก / Save'),
                ),
              ],
            );
          },
        );
      },
    );

    firstNameController.dispose();
    lastNameController.dispose();
    nicknameController.dispose();
    ageController.dispose();
    phoneController.dispose();
    lineIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    currentActivityController.dispose();
    travelTimeController.dispose();
    scheduleNotesController.dispose();
    subjectsController.dispose();
  }

  Future<void> _showDeleteTutorDialog(Tutor tutor) async {
    bool isDeleting = false;
    final bool? deleted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('ลบผู้ใช้ / Delete tutor'),
              content: Text('ยืนยันการลบ ${tutor.nickname} ออกจากระบบหรือไม่? / Delete this tutor?'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ยกเลิก / Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final bool success = await this.context.read<AuthProvider>().deleteTutor(tutor.email);
                          if (!mounted) {
                            return;
                          }
                          if (!success) {
                            setDialogState(() => isDeleting = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('ลบไม่สำเร็จ / Unable to delete tutor')),
                            );
                            return;
                          }
                          Navigator.of(dialogContext).pop(true);
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ลบ / Delete'),
                ),
              ],
            );
          },
        );
      },
    );
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบ ${tutor.nickname} เรียบร้อย / Tutor removed')),
      );
    }
  }

  Future<void> _showStatusPicker(Tutor tutor) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        final List<String> options = List<String>.from(Tutor.statuses);
        if (!options.contains(tutor.status)) {
          options.add(tutor.status);
        }
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('เลือกสถานะผู้ใช้ / Select tutor status'),
              ),
              for (final String status in options)
                ListTile(
                  leading: Icon(
                    status == tutor.status ? Icons.radio_button_checked : Icons.radio_button_off,
                  ),
                  title: Text(status),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (status != tutor.status) {
                      _updateTutorStatus(tutor, status);
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateTutorStatus(Tutor tutor, String newStatus) async {
    final AuthProvider authProvider = context.read<AuthProvider>();
    final String? error = await authProvider.updateTutor(
      originalEmail: tutor.email,
      updatedTutor: tutor.copyWith(status: newStatus),
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('อัปเดตสถานะเรียบร้อย: $newStatus / Status updated')), 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ดแอดมิน / Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ / Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (BuildContext context, AuthProvider authProvider, _) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (!authProvider.isAdminLoggedIn) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรุณาล็อกอินก่อน / Please login as admin first',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/admin-login',
                    ),
                    child: const Text('ไปหน้าแอดมิน / Go to admin login'),
                  ),
                ],
              ),
            );
          }
          final List<Tutor> tutors = authProvider.tutors;
          if (tutors.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีติวเตอร์ในระบบ / No tutors registered yet'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tutors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final Tutor tutor = tutors[index];
              MemoryImage? avatarImage;
              if (tutor.profileImageBase64 != null && tutor.profileImageBase64!.isNotEmpty) {
                try {
                  avatarImage = MemoryImage(base64Decode(tutor.profileImageBase64!));
                } catch (_) {
                  avatarImage = null;
                }
              }
              final String phoneDisplay = tutor.phoneNumber.isEmpty ? '-' : tutor.phoneNumber;
              final String fullName = <String>[tutor.firstName, tutor.lastName]
                  .where((String value) => value.trim().isNotEmpty)
                  .join(' ');
              final bool hasExtraDetails = fullName.isNotEmpty ||
                  tutor.age.isNotEmpty ||
                  tutor.currentActivity.isNotEmpty ||
                  tutor.travelTime.isNotEmpty ||
                  tutor.scheduleNotes.isNotEmpty ||
                  tutor.subjects.isNotEmpty;
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarImage,
                          child: avatarImage == null
                              ? Text(tutor.nickname.isNotEmpty ? tutor.nickname.characters.first : '?')
                              : null,
                        ),
                        title: Text(tutor.nickname),
                        subtitle: Text(
                          <String>[
                            if (fullName.isNotEmpty) 'ชื่อจริง: $fullName',
                            'เบอร์: $phoneDisplay',
                            'อีเมล: ${tutor.email}',
                            'ไอดีไลน์: ${tutor.lineId}',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                      ),
                      if (hasExtraDetails)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tutor.age.isNotEmpty)
                                Text('อายุ: ${tutor.age}'),
                              if (tutor.currentActivity.isNotEmpty)
                                Text('สิ่งที่ทำ: ${tutor.currentActivity}'),
                              if (tutor.travelTime.isNotEmpty)
                                Text('เวลาเดินทาง: ${tutor.travelTime}'),
                              if (tutor.scheduleNotes.isNotEmpty)
                                Text('ตารางสอน: ${tutor.scheduleNotes}'),
                              if (tutor.subjects.isNotEmpty)
                                Text('วิชาที่สอน: ${tutor.subjects.join(', ')}'),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.start,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _showStatusPicker(tutor),
                              icon: const Icon(Icons.flag),
                              label: Text('สถานะ: ${tutor.status}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showEditTutorDialog(tutor),
                              icon: const Icon(Icons.edit),
                              label: const Text('แก้ไข / Edit'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showDeleteTutorDialog(tutor),
                              icon: const Icon(Icons.delete),
                              label: const Text('ลบ / Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
