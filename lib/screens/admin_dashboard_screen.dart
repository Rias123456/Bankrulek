import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// หน้าควบคุมสำหรับแอดมิน
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<void> _showEditTutorDialog(Tutor tutor) async {
    final TextEditingController nicknameController = TextEditingController(text: tutor.nickname);
    final TextEditingController phoneController = TextEditingController(text: tutor.phoneNumber);
    final TextEditingController lineIdController = TextEditingController(text: tutor.lineId);
    final TextEditingController emailController = TextEditingController(text: tutor.email);
    final TextEditingController passwordController = TextEditingController(text: tutor.password);
    final TextEditingController travelDurationController =
        TextEditingController(text: tutor.travelDuration);
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('แก้ไขข้อมูลผู้ใช้'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อเล่น',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'เบอร์โทร',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lineIdController,
                      decoration: const InputDecoration(
                        labelText: 'ไอดีไลน์',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'อีเมล',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'รหัสผ่าน',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: travelDurationController,
                      decoration: const InputDecoration(
                        labelText: 'ระยะเวลาเดินทางมาสอน',
                        hintText: 'เช่น 30 นาที',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final String nickname = nicknameController.text.trim();
                          final String phoneNumber = phoneController.text.trim();
                          final String lineId = lineIdController.text.trim();
                          final String email = emailController.text.trim();
                          final String password = passwordController.text.trim();
                          final String travelDuration = travelDurationController.text.trim();
                          if (nickname.isEmpty || phoneNumber.isEmpty || lineId.isEmpty || email.isEmpty || password.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณากรอกข้อมูลให้ครบถ้วน'),
                              ),
                            );
                            return;
                          }
                          if (!email.contains('@')) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('รูปแบบอีเมลไม่ถูกต้อง'),
                              ),
                            );
                            return;
                          }
                          if (travelDuration.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('กรุณาระบุระยะเวลาเดินทาง'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          final AuthProvider authProvider = this.context.read<AuthProvider>();
                          final Tutor updatedTutor = tutor.copyWith(
                            nickname: nickname,
                            phoneNumber: phoneNumber,
                            lineId: lineId,
                            email: email,
                            password: password,
                            travelDuration: travelDuration,
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
                            const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ')), 
                          );
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );

    nicknameController.dispose();
    phoneController.dispose();
    lineIdController.dispose();
    emailController.dispose();
    passwordController.dispose();
    travelDurationController.dispose();
  }

  Future<void> _showDeleteTutorDialog(Tutor tutor) async {
    bool isDeleting = false;
    final bool? deleted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('ลบผู้ใช้'),
              content: Text('ยืนยันการลบ ${tutor.nickname} ออกจากระบบหรือไม่?'),
              actions: [
                TextButton(
                  onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('ยกเลิก'),
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
                              const SnackBar(content: Text('ลบไม่สำเร็จ')),
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
                      : const Text('ลบ'),
                ),
              ],
            );
          },
        );
      },
    );
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ลบ ${tutor.nickname} เรียบร้อย')),
      );
    }
  }

  Future<void> _showTravelDurationEditor(Tutor tutor) async {
    final TextEditingController controller = TextEditingController(text: tutor.travelDuration);
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'แก้ไขระยะเวลาเดินทาง',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'ระยะเวลาเดินทางมาสอน',
                      hintText: 'เช่น 30 นาที',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving ? null : () => Navigator.of(sheetContext).pop(),
                          child: const Text('ยกเลิก'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final String value = controller.text.trim();
                                  if (value.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('กรุณาระบุระยะเวลาเดินทาง')),
                                    );
                                    return;
                                  }
                                  setState(() => isSaving = true);
                                  final AuthProvider authProvider = this.context.read<AuthProvider>();
                                  final String? error = await authProvider.updateTutor(
                                    originalEmail: tutor.email,
                                    updatedTutor: tutor.copyWith(travelDuration: value),
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  if (error != null) {
                                    setState(() => isSaving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error)),
                                    );
                                    return;
                                  }
                                  Navigator.of(sheetContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('อัปเดตระยะเวลาเดินทางเรียบร้อย: $value')),
                                  );
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('บันทึก'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ดแอดมิน'),
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
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
                    'กรุณาล็อกอินก่อน',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/admin-login',
                    ),
                    child: const Text('ไปหน้าแอดมิน'),
                  ),
                ],
              ),
            );
          }
          final List<Tutor> tutors = authProvider.tutors;
          if (tutors.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีติวเตอร์ในระบบ'),
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
                          'เบอร์: $phoneDisplay\nอีเมล: ${tutor.email}\nไอดีไลน์: ${tutor.lineId}',
                        ),
                        isThreeLine: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.start,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _showTravelDurationEditor(tutor),
                              icon: const Icon(Icons.timer),
                              label: Text(
                                tutor.travelDuration.isEmpty
                                    ? 'ระยะเวลาเดินทาง: ยังไม่ระบุ'
                                    : 'ระยะเวลาเดินทาง: ${tutor.travelDuration}',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showEditTutorDialog(tutor),
                              icon: const Icon(Icons.edit),
                              label: const Text('แก้ไข'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showDeleteTutorDialog(tutor),
                              icon: const Icon(Icons.delete),
                              label: const Text('ลบ'),
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
