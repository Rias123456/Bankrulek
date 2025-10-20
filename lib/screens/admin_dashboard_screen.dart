import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// หน้าควบคุมสำหรับแอดมิน
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum _TutorAction { edit, status, travel, delete }

class _ScheduleSelection {
  const _ScheduleSelection({
    required this.dayIndex,
    required this.startSlot,
    required this.endSlot,
  }) : assert(endSlot >= startSlot);

  final int dayIndex;
  final int startSlot;
  final int endSlot;

  int get durationSlots => math.max(0, endSlot - startSlot);
}

class _CachedSchedule {
  const _CachedSchedule({required this.raw, required this.blocks});

  final String? raw;
  final List<_ScheduleBlock> blocks;
}

class _ScheduleRowPainter extends CustomPainter {
  const _ScheduleRowPainter({
    required this.hourCount,
    required this.slotsPerHour,
    required this.colorScheme,
  });

  final int hourCount;
  final int slotsPerHour;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect roundedRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final Paint backgroundPaint = Paint()
      ..color = colorScheme.surfaceVariant.withOpacity(0.45)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(roundedRect, backgroundPaint);

    final Paint borderPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(roundedRect, borderPaint);

    final double hourWidth = size.width / math.max(1, hourCount);
    final Paint hourLinePaint = Paint()
      ..color = colorScheme.outlineVariant.withOpacity(0.6)
      ..strokeWidth = 1;
    for (int hour = 1; hour < hourCount; hour++) {
      final double dx = hour * hourWidth;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), hourLinePaint);
    }

    if (slotsPerHour > 1) {
      final double slotWidth = hourWidth / slotsPerHour;
      final Paint slotPaint = Paint()
        ..color = colorScheme.outlineVariant.withOpacity(0.2)
        ..strokeWidth = 1;
      for (int hour = 0; hour < hourCount; hour++) {
        for (int slot = 1; slot < slotsPerHour; slot++) {
          final double dx = hour * hourWidth + slot * slotWidth;
          canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), slotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScheduleRowPainter oldDelegate) {
    return hourCount != oldDelegate.hourCount ||
        slotsPerHour != oldDelegate.slotsPerHour ||
        colorScheme != oldDelegate.colorScheme;
  }
}

enum _ScheduleBlockType { teaching, unavailable }

class _ScheduleBlock {
  const _ScheduleBlock({
    required this.id,
    required this.dayIndex,
    required this.startSlot,
    required this.durationSlots,
    required this.type,
    this.note,
    this.date,
    this.isRecurring = false,
  });

  final int id;
  final int dayIndex;
  final int startSlot;
  final int durationSlots;
  final _ScheduleBlockType type;
  final String? note;
  final DateTime? date;
  final bool isRecurring;

  _ScheduleBlock copyWith({
    int? id,
    int? dayIndex,
    int? startSlot,
    int? durationSlots,
    _ScheduleBlockType? type,
    String? note,
    DateTime? date,
    bool? isRecurring,
  }) {
    return _ScheduleBlock(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      startSlot: startSlot ?? this.startSlot,
      durationSlots: durationSlots ?? this.durationSlots,
      type: type ?? this.type,
      note: note ?? this.note,
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  static _ScheduleBlock? fromJson(Map<String, dynamic> json) {
    final int? dayIndex = json['day'] as int? ?? json['dayIndex'] as int?;
    final int? startSlot = json['start'] as int? ?? json['startSlot'] as int?;
    final int? durationSlots = json['duration'] as int? ?? json['durationSlots'] as int?;
    final String? typeName = json['type'] as String?;
    if (dayIndex == null || startSlot == null || durationSlots == null || typeName == null) {
      return null;
    }
    final _ScheduleBlockType type = _ScheduleBlockType.values.firstWhere(
      (_ScheduleBlockType value) => value.name == typeName,
      orElse: () => _ScheduleBlockType.unavailable,
    );
    final String? note = json['note'] as String?;
    final int id = json['id'] is int ? json['id'] as int : -1;
    DateTime? parsedDate;
    final String? dateValue = json['date'] as String? ?? json['dateString'] as String?;
    if (dateValue != null && dateValue.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(dateValue);
      } catch (_) {
        parsedDate = null;
      }
    }
    final bool isRecurring = json['isRecurring'] is bool ? json['isRecurring'] as bool : false;
    return _ScheduleBlock(
      id: id,
      dayIndex: dayIndex,
      startSlot: startSlot,
      durationSlots: durationSlots > 0 ? durationSlots : 1,
      type: type,
      note: note,
      date: parsedDate,
      isRecurring: isRecurring,
    );
  }
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 8;
  static const int _scheduleEndHour = 20;
  static const int _minutesPerSlot = 30;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 52;
  static const double _dayLabelWidth = 72;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  final ScrollController _timelineScrollController = ScrollController();
  final Set<String> _selectedSubjects = <String>{};
  final Map<String, _CachedSchedule> _scheduleCache = <String, _CachedSchedule>{};

  _ScheduleSelection? _selectedRange;
  int? _draggingDayIndex;
  int? _dragAnchorSlot;

  int get _slotsPerHour => math.max(1, 60 ~/ _minutesPerSlot);

  int get _totalSlots => (_scheduleEndHour - _scheduleStartHour) * _slotsPerHour;

  double get _slotWidth => _scheduleHourWidth / _slotsPerHour;

  double get _gridWidth => _totalSlots * _slotWidth;

  @override
  void dispose() {
    _timelineScrollController.dispose();
    super.dispose();
  }

  Future<void> _showEditTutorDialog(Tutor tutor) async {
    final TextEditingController nicknameController = TextEditingController(text: tutor.nickname);
    final TextEditingController phoneController = TextEditingController(text: tutor.phoneNumber);
    final TextEditingController lineIdController = TextEditingController(text: tutor.lineId);
    final TextEditingController emailController = TextEditingController(text: tutor.email);
    final TextEditingController passwordController = TextEditingController(text: tutor.password);
    final TextEditingController travelDurationController =
        TextEditingController(text: tutor.travelDuration);
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
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'สถานะ',
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
                            status: selectedStatus,
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

  void _handleLogout() {
    context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/admin-login', (Route<dynamic> route) => false);
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
                title: Text('เลือกสถานะผู้ใช้'),
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
      SnackBar(content: Text('อัปเดตสถานะเรียบร้อย: $newStatus')),
    );
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
          TextButton.icon(
            onPressed: _handleLogout,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.logout),
            label: const Text('ออกจากระบบ'),
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
          final List<Tutor> sortedTutors = List<Tutor>.from(tutors)
            ..sort((Tutor a, Tutor b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
          final Set<String> allSubjects = sortedTutors
              .expand((Tutor tutor) => tutor.subjects)
              .where((String subject) => subject.trim().isNotEmpty)
              .map((String subject) => subject.trim())
              .toSet();
          final List<Tutor> filteredTutors = sortedTutors.where(_matchesFilters).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubjectFilterSection(allSubjects),
                const SizedBox(height: 16),
                _buildScheduleFilterCard(),
                const SizedBox(height: 16),
                _buildFilterSummary(filteredTutors.length, sortedTutors.length),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildTutorGrid(filteredTutors),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubjectFilterSection(Set<String> allSubjects) {
    final ThemeData theme = Theme.of(context);
    final List<String> sortedSubjects = allSubjects.toList()..sort((String a, String b) => a.compareTo(b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.icon(
              onPressed:
                  sortedSubjects.isEmpty ? null : () => _showSubjectFilterSheet(sortedSubjects),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(
                _selectedSubjects.isEmpty
                    ? 'เลือกวิชา'
                    : 'เลือกวิชา (${_selectedSubjects.length})',
              ),
            ),
            const SizedBox(width: 12),
            if (_selectedSubjects.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _selectedSubjects.clear()),
                icon: const Icon(Icons.clear),
                label: const Text('ล้างวิชา'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedSubjects.isEmpty)
          Text(
            'สามารถเลือกได้หลายวิชาเพื่อกรองครู',
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedSubjects.map((String subject) {
              return InputChip(
                label: Text(subject),
                onDeleted: () => setState(() => _selectedSubjects.remove(subject)),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _showSubjectFilterSheet(List<String> subjects) async {
    final Set<String> tempSelection = Set<String>.from(_selectedSubjects);
    final Set<String>? result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'เลือกวิชาที่ต้องการกรอง',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (subjects.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('ยังไม่มีข้อมูลวิชาในระบบ')),
                      )
                    else ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setModalState(() => tempSelection.clear()),
                          child: const Text('ล้างทั้งหมด'),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: subjects.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String subject = subjects[index];
                            final bool isSelected = tempSelection.contains(subject);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setModalState(() {
                                  if (value == true) {
                                    tempSelection.add(subject);
                                  } else {
                                    tempSelection.remove(subject);
                                  }
                                });
                              },
                              title: Text(subject),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('ยกเลิก'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(sheetContext).pop(Set<String>.from(tempSelection)),
                              child: const Text('ยืนยัน'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _selectedSubjects
          ..clear()
          ..addAll(result);
      });
    }
  }

  Widget _buildScheduleFilterCard() {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ตารางสอน',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_selectedRange != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedRange = null),
                    icon: const Icon(Icons.close),
                    label: const Text('ล้างเวลา'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScheduleGrid(),
            const SizedBox(height: 12),
            if (_selectedRange != null)
              Text(
                'ช่วงเวลาที่เลือก: ${_formatSelection(_selectedRange!)}',
                style: theme.textTheme.bodyMedium,
              )
            else
              Text(
                'แตะหรือกดค้างแล้วลากในตารางเพื่อเลือกช่วงเวลาที่ต้องการกรอง',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleGrid() {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      controller: _timelineScrollController,
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: _dayLabelWidth),
              for (int hour = 0; hour < _scheduleEndHour - _scheduleStartHour; hour++)
                Container(
                  width: _scheduleHourWidth,
                  alignment: Alignment.center,
                  child: Text(
                    '${_scheduleStartHour + hour}:00',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: List<Widget>.generate(_dayLabels.length, (int dayIndex) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: _dayLabelWidth,
                      child: Text(
                        _dayLabels[dayIndex],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (TapDownDetails details) =>
                          _handleTapSelection(dayIndex, details.localPosition.dx),
                      onLongPressStart: (LongPressStartDetails details) =>
                          _handleLongPressStart(dayIndex, details.localPosition.dx),
                      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) =>
                          _handleLongPressUpdate(dayIndex, details.localPosition.dx),
                      onLongPressEnd: (_) => _handleLongPressEnd(),
                      child: SizedBox(
                        width: _gridWidth,
                        height: _scheduleRowHeight,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(_gridWidth, _scheduleRowHeight),
                              painter: _ScheduleRowPainter(
                                hourCount: _scheduleEndHour - _scheduleStartHour,
                                slotsPerHour: _slotsPerHour,
                                colorScheme: theme.colorScheme,
                              ),
                            ),
                            if (_selectedRange?.dayIndex == dayIndex)
                              Positioned(
                                left: _selectedRange!.startSlot * _slotWidth,
                                top: 4,
                                bottom: 4,
                                child: Builder(
                                  builder: (BuildContext context) {
                                    final double left = _selectedRange!.startSlot * _slotWidth;
                                    final double desiredWidth = math.max(
                                      _slotWidth,
                                      (_selectedRange!.endSlot - _selectedRange!.startSlot) * _slotWidth,
                                    );
                                    final double maxWidth = math.max(0, _gridWidth - left);
                                    final double highlightWidth = math.min(maxWidth, desiredWidth);
                                    return Container(
                                      width: highlightWidth,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.colorScheme.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _handleTapSelection(int dayIndex, double localDx) {
    final int slot = _slotFromDx(localDx);
    setState(() {
      _selectedRange = _ScheduleSelection(
        dayIndex: dayIndex,
        startSlot: slot,
        endSlot: math.min(_totalSlots, slot + 1),
      );
      _draggingDayIndex = null;
      _dragAnchorSlot = null;
    });
  }

  void _handleLongPressStart(int dayIndex, double localDx) {
    final int slot = _slotFromDx(localDx);
    setState(() {
      _draggingDayIndex = dayIndex;
      _dragAnchorSlot = slot;
      _selectedRange = _ScheduleSelection(
        dayIndex: dayIndex,
        startSlot: slot,
        endSlot: math.min(_totalSlots, slot + 1),
      );
    });
  }

  void _handleLongPressUpdate(int dayIndex, double localDx) {
    if (_draggingDayIndex != dayIndex || _dragAnchorSlot == null) {
      return;
    }
    final int currentSlot = _slotFromDx(localDx);
    final int anchor = _dragAnchorSlot!;
    final int start = math.min(anchor, currentSlot);
    final int end = math.max(anchor, currentSlot) + 1;
    setState(() {
      _selectedRange = _ScheduleSelection(
        dayIndex: dayIndex,
        startSlot: start,
        endSlot: math.min(_totalSlots, end),
      );
    });
  }

  void _handleLongPressEnd() {
    setState(() {
      _draggingDayIndex = null;
      _dragAnchorSlot = null;
    });
  }

  int _slotFromDx(double dx) {
    final double safeDx = dx.isNaN ? 0 : dx;
    final double maxDx = math.max(0, _gridWidth - 0.01);
    final double clamped = safeDx.clamp(0, maxDx).toDouble();
    final int slot = (clamped / _slotWidth).floor();
    return _clampInt(slot, 0, _totalSlots - 1);
  }

  String _formatSelection(_ScheduleSelection selection) {
    final String dayLabel = _dayLabels[_clampInt(selection.dayIndex, 0, _dayLabels.length - 1)];
    final TimeOfDay startTime = _timeForSlot(selection.startSlot);
    final TimeOfDay endTime = _timeForSlot(selection.endSlot);
    return '$dayLabel ${_formatTimeOfDay(startTime)} - ${_formatTimeOfDay(endTime)}';
  }

  TimeOfDay _timeForSlot(int slot) {
    final int safeSlot = _clampInt(slot, 0, _totalSlots);
    final int totalMinutes = _scheduleStartHour * 60 + safeSlot * _minutesPerSlot;
    final int hour = totalMinutes ~/ 60;
    final int minute = totalMinutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildFilterSummary(int filteredCount, int totalCount) {
    final ThemeData theme = Theme.of(context);
    final bool hasSubjectFilter = _selectedSubjects.isNotEmpty;
    final bool hasTimeFilter = _selectedRange != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ครูในระบบ (${filteredCount.toString()}/${totalCount.toString()})',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (!hasSubjectFilter && !hasTimeFilter)
          Text(
            'กำลังแสดงครูทั้งหมด',
            style: theme.textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (hasSubjectFilter)
                Chip(
                  avatar: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text('วิชา ${_selectedSubjects.length} รายการ'),
                ),
              if (hasTimeFilter)
                Chip(
                  avatar: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(_formatSelection(_selectedRange!)),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTutorGrid(List<Tutor> tutors) {
    if (tutors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('ไม่พบครูที่ตรงกับตัวกรอง'),
            const SizedBox(height: 4),
            Text(
              'ลองปรับตัวกรองวิชาหรือช่วงเวลาใหม่อีกครั้ง',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int crossAxisCount = math.max(1, (width / 200).floor());
        return GridView.builder(
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: tutors.length,
          itemBuilder: (BuildContext context, int index) {
            final Tutor tutor = tutors[index];
            return _buildTutorTile(tutor);
          },
        );
      },
    );
  }

  Widget _buildTutorTile(Tutor tutor) {
    MemoryImage? avatarImage;
    if (tutor.profileImageBase64 != null && tutor.profileImageBase64!.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(tutor.profileImageBase64!));
      } catch (_) {
        avatarImage = null;
      }
    }
    return GestureDetector(
      onTap: () => _showEditTutorDialog(tutor),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? Text(
                              tutor.nickname.characters.isNotEmpty
                                  ? tutor.nickname.characters.first
                                  : '?',
                              style: Theme.of(context).textTheme.titleLarge,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tutor.nickname.isEmpty ? 'ไม่ระบุชื่อเล่น' : tutor.nickname,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: _buildTutorMenu(tutor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorMenu(Tutor tutor) {
    return PopupMenuButton<_TutorAction>(
      tooltip: 'ตัวเลือกเพิ่มเติม',
      onSelected: (_TutorAction action) {
        switch (action) {
          case _TutorAction.edit:
            _showEditTutorDialog(tutor);
            break;
          case _TutorAction.status:
            _showStatusPicker(tutor);
            break;
          case _TutorAction.travel:
            _showTravelDurationEditor(tutor);
            break;
          case _TutorAction.delete:
            _showDeleteTutorDialog(tutor);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        return <PopupMenuEntry<_TutorAction>>[
          const PopupMenuItem<_TutorAction>(
            value: _TutorAction.edit,
            child: Text('แก้ไขข้อมูล'),
          ),
          const PopupMenuItem<_TutorAction>(
            value: _TutorAction.status,
            child: Text('เปลี่ยนสถานะ'),
          ),
          const PopupMenuItem<_TutorAction>(
            value: _TutorAction.travel,
            child: Text('แก้ไขเวลาเดินทาง'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<_TutorAction>(
            value: _TutorAction.delete,
            child: Text(
              'ลบผู้ใช้',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ];
      },
      icon: const Icon(Icons.more_vert),
    );
  }

  bool _matchesFilters(Tutor tutor) {
    if (!_matchesSubjectFilter(tutor)) {
      return false;
    }
    if (!_matchesTimeFilter(tutor)) {
      return false;
    }
    return true;
  }

  bool _matchesSubjectFilter(Tutor tutor) {
    if (_selectedSubjects.isEmpty) {
      return true;
    }
    if (tutor.subjects.isEmpty) {
      return false;
    }
    for (final String subject in tutor.subjects) {
      final String trimmed = subject.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (_selectedSubjects.contains(trimmed)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesTimeFilter(Tutor tutor) {
    if (_selectedRange == null) {
      return true;
    }
    final List<_ScheduleBlock> blocks = _getScheduleBlocksFor(tutor);
    if (blocks.isEmpty) {
      return true;
    }
    final _ScheduleSelection selection = _selectedRange!;
    for (final _ScheduleBlock block in blocks) {
      if (!_blockAppliesToDay(block, selection.dayIndex)) {
        continue;
      }
      if (_selectionOverlapsBlock(selection, block)) {
        return false;
      }
    }
    return true;
  }

  List<_ScheduleBlock> _getScheduleBlocksFor(Tutor tutor) {
    final String cacheKey = tutor.email.toLowerCase();
    final String? raw = tutor.teachingSchedule;
    final _CachedSchedule? cached = _scheduleCache[cacheKey];
    if (cached != null && cached.raw == raw) {
      return cached.blocks;
    }
    final List<_ScheduleBlock> parsed = _parseScheduleBlocks(raw);
    _scheduleCache[cacheKey] = _CachedSchedule(raw: raw, blocks: parsed);
    return parsed;
  }

  List<_ScheduleBlock> _parseScheduleBlocks(String? raw) {
    if (raw == null) {
      return const <_ScheduleBlock>[];
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.startsWith(_scheduleSerializationPrefix)) {
      return const <_ScheduleBlock>[];
    }
    try {
      final String payload = trimmed.substring(_scheduleSerializationPrefix.length);
      final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
      final List<dynamic> blockList = (data['blocks'] as List<dynamic>?) ?? <dynamic>[];
      final int sourceMinutesPerSlot =
          (data['minutesPerSlot'] is int && (data['minutesPerSlot'] as int) > 0)
              ? data['minutesPerSlot'] as int
              : _minutesPerSlot;
      final List<_ScheduleBlock> parsed = <_ScheduleBlock>[];
      for (final dynamic entry in blockList) {
        Map<String, dynamic>? blockMap;
        if (entry is Map<String, dynamic>) {
          blockMap = entry;
        } else if (entry is Map) {
          blockMap = Map<String, dynamic>.from(entry as Map);
        }
        if (blockMap == null) {
          continue;
        }
        final _ScheduleBlock? rawBlock = _ScheduleBlock.fromJson(blockMap);
        if (rawBlock == null) {
          continue;
        }
        final int safeDay = _clampInt(rawBlock.dayIndex, 0, _dayLabels.length - 1);
        final int startSlotMinutes = rawBlock.startSlot * sourceMinutesPerSlot;
        final int durationMinutes = math.max(0, rawBlock.durationSlots) * sourceMinutesPerSlot;
        final int convertedStart = startSlotMinutes ~/ _minutesPerSlot;
        final int convertedDuration = durationMinutes <= 0
            ? 0
            : ((durationMinutes - 1) ~/ _minutesPerSlot) + 1;
        final int safeStart = _clampInt(convertedStart, 0, _totalSlots - 1);
        final int maxDuration = _totalSlots - safeStart;
        if (maxDuration <= 0) {
          continue;
        }
        final int safeDuration = convertedDuration <= 0
            ? 0
            : _clampInt(convertedDuration, 1, maxDuration);
        if (safeDuration <= 0) {
          continue;
        }
        parsed.add(
          rawBlock.copyWith(
            dayIndex: safeDay,
            startSlot: safeStart,
            durationSlots: safeDuration,
            date: rawBlock.date != null ? _normalizeDate(rawBlock.date!) : null,
          ),
        );
      }
      parsed.sort((_ScheduleBlock a, _ScheduleBlock b) {
        final int dayCompare = a.dayIndex.compareTo(b.dayIndex);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.startSlot.compareTo(b.startSlot);
      });
      return List<_ScheduleBlock>.unmodifiable(parsed);
    } catch (_) {
      return const <_ScheduleBlock>[];
    }
  }

  bool _blockAppliesToDay(_ScheduleBlock block, int dayIndex) {
    if (block.isRecurring || block.date == null) {
      return block.dayIndex == dayIndex;
    }
    return _dayIndexFromDate(block.date!) == dayIndex;
  }

  bool _selectionOverlapsBlock(_ScheduleSelection selection, _ScheduleBlock block) {
    final int selectionStart = selection.startSlot;
    final int selectionEnd = selection.endSlot;
    final int blockStart = block.startSlot;
    final int blockEnd = block.startSlot + block.durationSlots;
    return math.max(selectionStart, blockStart) < math.min(selectionEnd, blockEnd);
  }

  int _dayIndexFromDate(DateTime date) {
    final DateTime normalized = _normalizeDate(date);
    switch (normalized.weekday) {
      case DateTime.saturday:
        return 0;
      case DateTime.sunday:
        return 1;
      case DateTime.monday:
        return 2;
      case DateTime.tuesday:
        return 3;
      case DateTime.wednesday:
        return 4;
      case DateTime.thursday:
        return 5;
      case DateTime.friday:
        return 6;
      default:
        return 0;
    }
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  int _clampInt(int value, int minValue, int maxValue) {
    if (maxValue <= minValue) {
      return minValue;
    }
    return math.min(math.max(value, minValue), maxValue);
  }
}
