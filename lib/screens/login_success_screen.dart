import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';
import '../widgets/study_table.dart';


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
  'อังกฤษ': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
  'ไทย': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
  'สังคม': <String>['ประถม', 'มัธยมต้น', 'มัธยมปลาย'],
  'ฟิสิก': <String>[],   
  'เคมี': <String>[],    
  'ชีวะ': <String>[],    
};

static final List<String> _orderedSubjectOptions = _subjectLevels.entries
    .expand(
      (entry) => entry.value.isEmpty
          ? [entry.key]
          : entry.value.map((level) => '${entry.key} ($level)'),
    )
    .toList(growable: false);


  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _lineIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _currentActivityController = TextEditingController();
  final TextEditingController _travelDurationController = TextEditingController();
  List<String> _selectedSubjects = <String>[];
  String? _profileImageBase64;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSaving = false;
  String? _lastSyncedSignature;
  List<ScheduleBlock> _scheduleBlocks = <ScheduleBlock>[];
  int _nextBlockId = 1;
  String? _legacyScheduleNote;

  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 7;
  static const int _scheduleEndHour = 21;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  int get _totalSlots => _scheduleEndHour - _scheduleStartHour;

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _lineIdController.dispose();
    _phoneController.dispose();
    _currentActivityController.dispose();
    _travelDurationController.dispose();
    super.dispose();
  }

  void _synchronizeControllers(Tutor tutor) {
    final String signature = _buildTutorSignature(tutor);
    if (_lastSyncedSignature == signature) {
      return;
    }

    final String combinedName = '${tutor.firstName} ${tutor.lastName}'.trim();
    _fullNameController.text = combinedName;
    _nicknameController.text = tutor.nickname;
    _lineIdController.text = tutor.lineId;
    _phoneController.text = tutor.phoneNumber;
    _currentActivityController.text = tutor.currentActivity;
    _travelDurationController.text = tutor.travelDuration;
    _selectedSubjects = List<String>.from(tutor.subjects);
    _loadScheduleFromString(tutor.teachingSchedule);
    _profileImageBase64 = tutor.profileImageBase64;
    _lastSyncedSignature = signature;
  }

  String _buildTutorSignature(Tutor tutor) {
    final String subjectsSignature = tutor.subjects.join(',');
    final String scheduleSignature = tutor.teachingSchedule ?? '';
    final String imageSignature = tutor.profileImageBase64 ?? '';
    return '${tutor.email}|${tutor.firstName}|${tutor.lastName}|${tutor.nickname}|${tutor.lineId}|${tutor.phoneNumber}|${tutor.currentActivity}|${tutor.status}|${tutor.travelDuration}|'
        '$subjectsSignature|$scheduleSignature|$imageSignature';
  }

  void _loadScheduleFromString(String? raw) {
    _scheduleBlocks = <ScheduleBlock>[];
    _legacyScheduleNote = null;
    _nextBlockId = 1;

    if (raw == null || raw.trim().isEmpty) {
      return;
    }

    final String trimmed = raw.trim();
    if (trimmed.startsWith(_scheduleSerializationPrefix)) {
      final String payload = trimmed.substring(_scheduleSerializationPrefix.length);
      try {
        final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
        final List<dynamic> blockList = (data['blocks'] as List<dynamic>?) ?? <dynamic>[];
        final List<ScheduleBlock> parsedBlocks = <ScheduleBlock>[];
        final Set<int> usedIds = <int>{};
        int provisionalId = 0;
        for (final dynamic entry in blockList) {
          Map<String, dynamic>? mapEntry;
          if (entry is Map<String, dynamic>) {
            mapEntry = entry;
          } else if (entry is Map) {
            mapEntry = Map<String, dynamic>.from(entry as Map);
          }
          if (mapEntry == null) {
            continue;
          }
          final ScheduleBlock? parsed = ScheduleBlock.fromJson(mapEntry);
          if (parsed == null) {
            continue;
          }
          final int safeDay = _clampInt(parsed.dayIndex, 0, _dayLabels.length - 1);
          final int safeStart = _clampInt(parsed.startSlot, 0, _totalSlots - 1);
          final int maxDuration = _totalSlots - safeStart;
          if (maxDuration <= 0) {
            continue;
          }
          final int safeDuration = _clampInt(parsed.durationSlots, 1, maxDuration);
          int resolvedId = parsed.id;
          if (resolvedId <= 0 || usedIds.contains(resolvedId)) {
            do {
              provisionalId++;
            } while (usedIds.contains(provisionalId));
            resolvedId = provisionalId;
          }
          final ScheduleBlock sanitized = parsed.copyWith(
            id: resolvedId,
            dayIndex: safeDay,
            startSlot: safeStart,
            durationSlots: safeDuration,
          );
          if (_canPlaceBlock(sanitized.dayIndex, sanitized.startSlot, sanitized.durationSlots, existing: parsedBlocks)) {
            parsedBlocks.add(sanitized);
            usedIds.add(resolvedId);
          }
        }
        parsedBlocks.sort((ScheduleBlock a, ScheduleBlock b) {
          final int dayCompare = a.dayIndex.compareTo(b.dayIndex);
          if (dayCompare != 0) {
            return dayCompare;
          }
          return a.startSlot.compareTo(b.startSlot);
        });
        _scheduleBlocks = parsedBlocks;
        if (usedIds.isNotEmpty) {
          _nextBlockId = usedIds.reduce(math.max) + 1;
        } else {
          _nextBlockId = 1;
        }
        return;
      } catch (_) {
        // Fallback to legacy text if parsing fails.
      }
    }

    _legacyScheduleNote = trimmed;
  }

  String _serializeScheduleBlocks() {
    if (_scheduleBlocks.isEmpty) {
      return '';
    }
    _sortBlocks();
    final Map<String, dynamic> data = <String, dynamic>{
      'format': 'grid-v1',
      'startHour': _scheduleStartHour,
      'endHour': _scheduleEndHour,
      'blocks': _scheduleBlocks.map((ScheduleBlock block) => block.toJson()).toList(),
    };
    return '$_scheduleSerializationPrefix${jsonEncode(data)}';
  }

  void _sortBlocks() {
    _scheduleBlocks.sort((ScheduleBlock a, ScheduleBlock b) {
      final int dayCompare = a.dayIndex.compareTo(b.dayIndex);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.startSlot.compareTo(b.startSlot);
    });
  }

  int _generateBlockId() => _nextBlockId++;

  void _handleBlocksChanged(List<ScheduleBlock> blocks) {
    setState(() {
      _scheduleBlocks = List<ScheduleBlock>.from(blocks);
    });
  }

  void _handleLegacyNoteChanged(String? note) {
    setState(() {
      _legacyScheduleNote = note;
    });
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
            StudyTable(
              blocks: _scheduleBlocks,
              onBlocksChanged: _handleBlocksChanged,
              generateBlockId: _generateBlockId,
              legacyNote: _legacyScheduleNote,
              onLegacyNoteChanged: _handleLegacyNoteChanged,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      label: Text(
        label,
        softWrap: true,
        maxLines: 3,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelAlignment: FloatingLabelAlignment.start,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: alignLabelWithHint,
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
    int? minLines,
    int? maxLines,
    bool expands = false,
    bool alignLabelWithHint = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      minLines: minLines,
      maxLines: maxLines,
      expands: expands,
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        alignLabelWithHint: alignLabelWithHint,
      ),
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
      body: SafeArea(
        child: Consumer<AuthProvider>(
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHeaderSection(tutor),
                    const SizedBox(height: 12),
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
      ),
    );
  }
}

