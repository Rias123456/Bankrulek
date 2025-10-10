import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/primary_button.dart';

enum ScheduleBlockType { teaching, unavailable }

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.dayIndex,
    required this.startSlot,
    required this.durationSlots,
    required this.type,
    this.note,
  });

  final int id;
  final int dayIndex;
  final int startSlot;
  final int durationSlots;
  final ScheduleBlockType type;
  final String? note;

  ScheduleBlock copyWith({
    int? id,
    int? dayIndex,
    int? startSlot,
    int? durationSlots,
    ScheduleBlockType? type,
    String? note,
    bool clearNote = false,
  }) {
    final ScheduleBlockType resolvedType = type ?? this.type;
    String? resolvedNote;
    if (clearNote) {
      resolvedNote = null;
    } else if (resolvedType == ScheduleBlockType.teaching) {
      resolvedNote = note ?? this.note;
      if (resolvedNote != null && resolvedNote.trim().isEmpty) {
        resolvedNote = null;
      }
    } else {
      resolvedNote = null;
    }
    return ScheduleBlock(
      id: id ?? this.id,
      dayIndex: dayIndex ?? this.dayIndex,
      startSlot: startSlot ?? this.startSlot,
      durationSlots: durationSlots ?? this.durationSlots,
      type: resolvedType,
      note: resolvedNote,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'day': dayIndex,
      'start': startSlot,
      'duration': durationSlots,
      'type': type.name,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  static ScheduleBlock? fromJson(Map<String, dynamic> json) {
    final int? dayIndex = json['day'] as int? ?? json['dayIndex'] as int?;
    final int? startSlot = json['start'] as int? ?? json['startSlot'] as int?;
    final int? durationSlots = json['duration'] as int? ?? json['durationSlots'] as int?;
    final String? typeName = json['type'] as String?;
    if (dayIndex == null || startSlot == null || durationSlots == null || typeName == null) {
      return null;
    }
    final ScheduleBlockType type = ScheduleBlockType.values.firstWhere(
      (ScheduleBlockType value) => value.name == typeName,
      orElse: () => ScheduleBlockType.unavailable,
    );
    final String? note = json['note'] as String?;
    final int id = json['id'] is int ? json['id'] as int : -1;
    return ScheduleBlock(
      id: id,
      dayIndex: dayIndex,
      startSlot: startSlot,
      durationSlots: durationSlots > 0 ? durationSlots : 1,
      type: type,
      note: note,
    );
  }
}

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
  int? _draggingBlockId;
  double _dragAccumulatedDx = 0;
  double _dragAccumulatedDy = 0;
  bool _isDragPrimed = false;
  bool _isRangeSelecting = false;
  int? _rangeSelectionDayIndex;
  int? _rangeSelectionAnchorSlot;
  _SelectionRange? _currentSelectionRange;
  bool _rangeSelectionMoved = false;

  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 7;
  static const int _scheduleEndHour = 21;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 72;
  static const double _dayLabelWidth = 80;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  int get _totalSlots => (_scheduleEndHour - _scheduleStartHour) * 2;

  double get _slotWidth => _scheduleHourWidth / 2;

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

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  bool _canPlaceBlock(
    int dayIndex,
    int startSlot,
    int durationSlots, {
    int? ignoreId,
    List<ScheduleBlock>? existing,
  }) {
    if (startSlot < 0 || durationSlots <= 0 || startSlot + durationSlots > _totalSlots) {
      return false;
    }
    final List<ScheduleBlock> source = existing ?? _scheduleBlocks;
    for (final ScheduleBlock block in source) {
      if (ignoreId != null && block.id == ignoreId) {
        continue;
      }
      if (block.dayIndex != dayIndex) {
        continue;
      }
      final int blockEnd = block.startSlot + block.durationSlots;
      final int newEnd = startSlot + durationSlots;
      if (startSlot < blockEnd && newEnd > block.startSlot) {
        return false;
      }
    }
    return true;
  }

  int _calculateMaxDuration(int dayIndex, int startSlot, int? ignoreId) {
    final int maxSlots = _totalSlots - startSlot;
    if (maxSlots <= 0) {
      return 0;
    }
    final List<ScheduleBlock> dayBlocks = _scheduleBlocks
        .where(
          (ScheduleBlock block) =>
              block.dayIndex == dayIndex && (ignoreId == null || block.id != ignoreId),
        )
        .toList()
      ..sort((ScheduleBlock a, ScheduleBlock b) => a.startSlot.compareTo(b.startSlot));
    int available = maxSlots;
    for (final ScheduleBlock block in dayBlocks) {
      final int blockStart = block.startSlot;
      final int blockEnd = block.startSlot + block.durationSlots;
      if (blockStart <= startSlot && blockEnd > startSlot) {
        return 0;
      }
      if (blockStart > startSlot) {
        available = math.min(available, blockStart - startSlot);
        break;
      }
    }
    return available;
  }

  String _formatDurationLabel(int slots) {
    final int minutes = slots * 30;
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;
    if (hours > 0 && remainingMinutes > 0) {
      return '$hours ชม. ${remainingMinutes.toString()} นาที';
    }
    if (hours > 0) {
      return '$hours ชม.';
    }
    return '$remainingMinutes นาที';
  }

  String _formatTimeLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _formatSlotRange(int startSlot, int durationSlots) {
    final DateTime base = DateTime(2020, 1, 1, _scheduleStartHour);
    final DateTime start = base.add(Duration(minutes: startSlot * 30));
    final DateTime end = base.add(Duration(minutes: (startSlot + durationSlots) * 30));
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _slotFromDx(double dx) {
    final double maxWidth = _totalSlots * _slotWidth;
    final double adjustedDx = dx.clamp(0, maxWidth - 0.001);
    return _clampInt((adjustedDx / _slotWidth).floor(), 0, _totalSlots - 1);
  }

  _SelectionRange _resolveSelectionRange(int dayIndex, int anchorSlot, int targetSlot) {
    final int normalizedTarget = _clampInt(targetSlot, 0, _totalSlots - 1);
    int start = math.min(anchorSlot, normalizedTarget);
    int end = math.max(anchorSlot, normalizedTarget);
    if (!_canPlaceBlock(dayIndex, anchorSlot, 1)) {
      return _SelectionRange(startSlot: anchorSlot, durationSlots: 1);
    }
    if (normalizedTarget >= anchorSlot) {
      while (end > anchorSlot && !_canPlaceBlock(dayIndex, start, end - start + 1)) {
        end -= 1;
      }
      if (!_canPlaceBlock(dayIndex, start, end - start + 1)) {
        start = anchorSlot;
        end = anchorSlot;
      }
    } else {
      while (start < anchorSlot && !_canPlaceBlock(dayIndex, start, end - start + 1)) {
        start += 1;
      }
      if (!_canPlaceBlock(dayIndex, start, end - start + 1)) {
        start = anchorSlot;
        end = anchorSlot;
      }
    }
    return _SelectionRange(startSlot: start, durationSlots: end - start + 1);
  }

  void _startRangeSelection(int dayIndex, double dx) {
    final int slot = _slotFromDx(dx);
    if (!_canPlaceBlock(dayIndex, slot, 1)) {
      _cancelRangeSelection();
      return;
    }
    setState(() {
      _isRangeSelecting = true;
      _rangeSelectionDayIndex = dayIndex;
      _rangeSelectionAnchorSlot = slot;
      _currentSelectionRange = _SelectionRange(startSlot: slot, durationSlots: 1);
      _rangeSelectionMoved = false;
    });
  }

  void _updateRangeSelection(double dx) {
    if (!_isRangeSelecting || _rangeSelectionDayIndex == null || _rangeSelectionAnchorSlot == null) {
      return;
    }
    final int targetSlot = _slotFromDx(dx);
    final int anchor = _rangeSelectionAnchorSlot!;
    final _SelectionRange resolved = _resolveSelectionRange(_rangeSelectionDayIndex!, anchor, targetSlot);
    final bool moved = targetSlot != anchor;
    if (_currentSelectionRange?.startSlot != resolved.startSlot ||
        _currentSelectionRange?.durationSlots != resolved.durationSlots) {
      setState(() {
        _currentSelectionRange = resolved;
        _rangeSelectionMoved = _rangeSelectionMoved || moved;
      });
    } else if (moved && !_rangeSelectionMoved) {
      setState(() {
        _rangeSelectionMoved = true;
      });
    }
  }

  Future<void> _finishRangeSelection({DragEndDetails? details, bool cancelled = false}) async {
    if (!_isRangeSelecting) {
      return;
    }
    final _SelectionRange? range = _currentSelectionRange;
    final int? dayIndex = _rangeSelectionDayIndex;
    final bool hasMoved = _rangeSelectionMoved;
    if (cancelled || range == null || dayIndex == null) {
      _cancelRangeSelection();
      return;
    }
    if (details != null) {
      final double speed = details.velocity.pixelsPerSecond.distance;
      if (speed > 900 && hasMoved) {
        _cancelRangeSelection();
        return;
      }
    }

    setState(() {
      _isRangeSelecting = false;
      _rangeSelectionDayIndex = null;
      _rangeSelectionAnchorSlot = null;
      _currentSelectionRange = null;
      _rangeSelectionMoved = false;
    });

    if (!_canPlaceBlock(dayIndex, range.startSlot, range.durationSlots)) {
      return;
    }

    final ScheduleBlockType? type = await _showBlockTypeChooser();
    if (type == null) {
      return;
    }

    final _BlockDetails? detailsResult = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      startSlot: range.startSlot,
      initialDuration: range.durationSlots,
    );
    if (detailsResult == null) {
      return;
    }

    if (!_canPlaceBlock(detailsResult.dayIndex, range.startSlot, detailsResult.durationSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }

    final ScheduleBlock newBlock = ScheduleBlock(
      id: _nextBlockId++,
      dayIndex: detailsResult.dayIndex,
      startSlot: range.startSlot,
      durationSlots: detailsResult.durationSlots,
      type: type,
      note: type == ScheduleBlockType.teaching ? detailsResult.note : null,
    );

    setState(() {
      _scheduleBlocks = <ScheduleBlock>[..._scheduleBlocks, newBlock];
      _legacyScheduleNote = null;
      _sortBlocks();
    });
  }

  void _cancelRangeSelection() {
    if (!_isRangeSelecting && _currentSelectionRange == null) {
      return;
    }
    setState(() {
      _isRangeSelecting = false;
      _rangeSelectionDayIndex = null;
      _rangeSelectionAnchorSlot = null;
      _currentSelectionRange = null;
      _rangeSelectionMoved = false;
    });
  }

  Future<void> _handleGridTap(int dayIndex, double dx) async {
    final int slot = _slotFromDx(dx);
    if (!_canPlaceBlock(dayIndex, slot, 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final int maxDuration = _calculateMaxDuration(dayIndex, slot, null);
    if (maxDuration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final ScheduleBlockType? type = await _showBlockTypeChooser();
    if (type == null) {
      return;
    }
    final _BlockDetails? details = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      startSlot: slot,
    );
    if (details == null) {
      return;
    }
    if (!_canPlaceBlock(details.dayIndex, slot, details.durationSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final ScheduleBlock newBlock = ScheduleBlock(
      id: _nextBlockId++,
      dayIndex: details.dayIndex,
      startSlot: slot,
      durationSlots: details.durationSlots,
      type: type,
      note: type == ScheduleBlockType.teaching ? details.note : null,
    );
    setState(() {
      _scheduleBlocks = <ScheduleBlock>[..._scheduleBlocks, newBlock];
      _legacyScheduleNote = null;
      _sortBlocks();
    });
  }

  Future<ScheduleBlockType?> _showBlockTypeChooser() {
    return showModalBottomSheet<ScheduleBlockType>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                const SizedBox(height: 16),
                const Text(
                  'เลือกประเภทบล็อคเวลา',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBlockOption(
                  color: const Color(0xFFFFE4E1),
                  borderColor: const Color(0xFFB71C1C),
                  textColor: Colors.grey.shade700,
                  title: 'สอน',
                  subtitle: 'บันทึกคาบสอนและรายละเอียด',
                  onTap: () => Navigator.pop(context, ScheduleBlockType.teaching),
                ),
                const SizedBox(height: 12),
                _buildBlockOption(
                  color: Colors.grey.shade300,
                  borderColor: Colors.grey.shade500,
                  textColor: Colors.grey.shade800,
                  title: 'ไม่ว่าง',
                  subtitle: 'กันเวลาไว้สำหรับภารกิจอื่น',
                  onTap: () => Navigator.pop(context, ScheduleBlockType.unavailable),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBlockOption({
    required Color color,
    required Color borderColor,
    required Color textColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: textColor.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Future<_BlockDetails?> _collectBlockDetails({
    required ScheduleBlockType type,
    required int dayIndex,
    required int startSlot,
    int? initialDuration,
    String? initialNote,
    int? ignoreBlockId,
  }) async {
    final List<int> maxDurationPerDay = List<int>.generate(
      _dayLabels.length,
      (int index) => _calculateMaxDuration(index, startSlot, ignoreBlockId),
    );
    if (maxDurationPerDay.every((int value) => value <= 0)) {
      return null;
    }

    int selectedDay = dayIndex;
    if (maxDurationPerDay[selectedDay] <= 0) {
      final int fallbackIndex = maxDurationPerDay.indexWhere((int value) => value > 0);
      if (fallbackIndex == -1) {
        return null;
      }
      selectedDay = fallbackIndex;
    }

    int maxForSelectedDay = math.max(1, maxDurationPerDay[selectedDay]);
    int duration = initialDuration != null
        ? _clampInt(initialDuration, 1, maxForSelectedDay)
        : math.min(
            type == ScheduleBlockType.teaching ? math.min(2, maxForSelectedDay) : 1,
            maxForSelectedDay,
          );
    final TextEditingController noteController = TextEditingController(text: initialNote ?? '');

    final _BlockDetails? result = await showDialog<_BlockDetails>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool isTeaching = type == ScheduleBlockType.teaching;
            return AlertDialog(
              title: Text(isTeaching ? 'เพิ่มช่วงเวลาสอน' : 'ทำเครื่องหมายไม่ว่าง'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_dayLabels[selectedDay]} ${_formatSlotRange(startSlot, duration)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedDay,
                      decoration: const InputDecoration(labelText: 'วัน'),
                      items: List<DropdownMenuItem<int>>.generate(
                        _dayLabels.length,
                        (int index) {
                          final bool enabled = maxDurationPerDay[index] > 0;
                          return DropdownMenuItem<int>(
                            value: index,
                            enabled: enabled,
                            child: Row(
                              children: <Widget>[
                                Expanded(child: Text(_dayLabels[index])),
                                if (!enabled)
                                  Text(
                                    'เต็ม',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      onChanged: (int? value) {
                        if (value == null || maxDurationPerDay[value] <= 0) {
                          return;
                        }
                        setState(() {
                          selectedDay = value;
                          maxForSelectedDay = math.max(1, maxDurationPerDay[value]);
                          duration = _clampInt(duration, 1, maxForSelectedDay);
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isTeaching) ...<Widget>[
                      TextField(
                        controller: noteController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'รายละเอียดการสอน',
                          hintText: 'เช่น ชื่อวิชา หรือชื่อนักเรียน',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: <Widget>[
                        const Text('ระยะเวลา'),
                        const Spacer(),
                        IconButton(
                          onPressed: duration > 1
                              ? () => setState(() {
                                    duration = math.max(1, duration - 1);
                                  })
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          _formatDurationLabel(duration),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          onPressed: duration < maxForSelectedDay
                              ? () => setState(() {
                                    duration = math.min(maxForSelectedDay, duration + 1);
                                  })
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'คุณสามารถลากเพื่อย้ายบล็อคไปยังวันหรือเวลาอื่นได้ในภายหลัง',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!_canPlaceBlock(selectedDay, startSlot, duration, ignoreId: ignoreBlockId)) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
                      );
                      return;
                    }
                    Navigator.pop(
                      context,
                      _BlockDetails(
                        dayIndex: selectedDay,
                        durationSlots: duration,
                        note: isTeaching
                            ? (noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim())
                            : null,
                      ),
                    );
                  },
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );
    noteController.dispose();
    return result;
  }

  void _primeBlockDrag(ScheduleBlock block) {
    if (_draggingBlockId == block.id && _isDragPrimed) {
      return;
    }
    setState(() {
      _draggingBlockId = block.id;
      _isDragPrimed = true;
      _dragAccumulatedDx = 0;
      _dragAccumulatedDy = 0;
    });
  }

  void _startDraggingBlock(ScheduleBlock block) {
    if (_draggingBlockId != block.id || !_isDragPrimed) {
      setState(() {
        _draggingBlockId = block.id;
        _isDragPrimed = true;
      });
    }
    _dragAccumulatedDx = 0;
    _dragAccumulatedDy = 0;
  }

  void _updateDraggingBlock(ScheduleBlock block, Offset delta) {
    if (_draggingBlockId != block.id) {
      _startDraggingBlock(block);
    }
    _dragAccumulatedDx += delta.dx;
    _dragAccumulatedDy += delta.dy;

    int horizontalSteps = 0;
    int verticalSteps = 0;

    final double horizontalThreshold = _slotWidth * 0.4;
    final double verticalThreshold = _scheduleRowHeight * 0.35;

    while (_dragAccumulatedDx >= horizontalThreshold) {
      horizontalSteps += 1;
      _dragAccumulatedDx -= _slotWidth;
    }
    while (_dragAccumulatedDx <= -horizontalThreshold) {
      horizontalSteps -= 1;
      _dragAccumulatedDx += _slotWidth;
    }

    while (_dragAccumulatedDy >= verticalThreshold) {
      verticalSteps += 1;
      _dragAccumulatedDy -= _scheduleRowHeight;
    }
    while (_dragAccumulatedDy <= -verticalThreshold) {
      verticalSteps -= 1;
      _dragAccumulatedDy += _scheduleRowHeight;
    }

    if (horizontalSteps == 0 && verticalSteps == 0) {
      return;
    }
    final int newDay = _clampInt(block.dayIndex + verticalSteps, 0, _dayLabels.length - 1);
    final int newStart = _clampInt(block.startSlot + horizontalSteps, 0, _totalSlots - block.durationSlots);
    if (!_canPlaceBlock(newDay, newStart, block.durationSlots, ignoreId: block.id)) {
      return;
    }

    setState(() {
      _scheduleBlocks = _scheduleBlocks
          .map(
            (ScheduleBlock current) => current.id == block.id
                ? current.copyWith(dayIndex: newDay, startSlot: newStart)
                : current,
          )
          .toList();
      _sortBlocks();
      _isDragPrimed = true;
    });
  }

  void _endDraggingBlock() {
    if (_draggingBlockId == null && !_isDragPrimed) {
      _dragAccumulatedDx = 0;
      _dragAccumulatedDy = 0;
      return;
    }
    setState(() {
      _draggingBlockId = null;
      _isDragPrimed = false;
      _dragAccumulatedDx = 0;
      _dragAccumulatedDy = 0;
    });
  }

  Future<void> _onBlockTapped(ScheduleBlock block) async {
    final _BlockAction? action = await showModalBottomSheet<_BlockAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        final bool isTeaching = block.type == ScheduleBlockType.teaching;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Text(
                  '${_dayLabels[block.dayIndex]} ${_formatSlotRange(block.startSlot, block.durationSlots)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('สถานะ: ${isTeaching ? 'สอน' : 'ไม่ว่าง'}'),
                if (isTeaching && block.note != null && block.note!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('รายละเอียด: ${block.note}'),
                ],
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('แก้ไขรายละเอียด'),
                  onTap: () => Navigator.pop(context, _BlockAction.edit),
                ),
                ListTile(
                  leading: Icon(isTeaching ? Icons.block : Icons.school_outlined),
                  title: Text(isTeaching ? 'เปลี่ยนเป็นไม่ว่าง' : 'เปลี่ยนเป็นช่วงสอน'),
                  onTap: () => Navigator.pop(context, _BlockAction.toggleType),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  title: const Text('ลบบล็อคนี้'),
                  onTap: () => Navigator.pop(context, _BlockAction.delete),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    switch (action) {
      case _BlockAction.edit:
        final _BlockDetails? details = await _collectBlockDetails(
          type: block.type,
          dayIndex: block.dayIndex,
          startSlot: block.startSlot,
          initialDuration: block.durationSlots,
          initialNote: block.note,
          ignoreBlockId: block.id,
        );
        if (details != null) {
          if (!_canPlaceBlock(details.dayIndex, block.startSlot, details.durationSlots, ignoreId: block.id)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
            );
            return;
          }
          setState(() {
            _scheduleBlocks = _scheduleBlocks
                .map(
                  (ScheduleBlock current) => current.id == block.id
                      ? current.copyWith(
                          dayIndex: details.dayIndex,
                          startSlot: block.startSlot,
                          durationSlots: details.durationSlots,
                          note: block.type == ScheduleBlockType.teaching ? details.note : null,
                        )
                      : current,
                )
                .toList();
            _sortBlocks();
          });
        }
        break;
      case _BlockAction.toggleType:
        if (block.type == ScheduleBlockType.teaching) {
          setState(() {
            _scheduleBlocks = _scheduleBlocks
                .map(
                  (ScheduleBlock current) => current.id == block.id
                      ? current.copyWith(type: ScheduleBlockType.unavailable, clearNote: true)
                      : current,
                )
                .toList();
          });
        } else {
          final _BlockDetails? details = await _collectBlockDetails(
            type: ScheduleBlockType.teaching,
            dayIndex: block.dayIndex,
            startSlot: block.startSlot,
            initialDuration: block.durationSlots,
            ignoreBlockId: block.id,
          );
          if (details != null) {
            if (!_canPlaceBlock(details.dayIndex, block.startSlot, details.durationSlots, ignoreId: block.id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
              );
              return;
            }
            setState(() {
              _scheduleBlocks = _scheduleBlocks
                  .map(
                    (ScheduleBlock current) => current.id == block.id
                        ? current.copyWith(
                            dayIndex: details.dayIndex,
                            startSlot: block.startSlot,
                            type: ScheduleBlockType.teaching,
                            durationSlots: details.durationSlots,
                            note: details.note,
                          )
                        : current,
                  )
                  .toList();
              _sortBlocks();
            });
          }
        }
        break;
      case _BlockAction.delete:
        setState(() {
          _scheduleBlocks = _scheduleBlocks.where((ScheduleBlock current) => current.id != block.id).toList();
        });
        break;
    }
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
    final List<String> nameParts = _fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    final String parsedFirstName =
        nameParts.isNotEmpty ? nameParts.first : currentTutor.firstName;
    final String parsedLastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : currentTutor.lastName;

    final Tutor updatedTutor = currentTutor.copyWith(
      firstName: parsedFirstName,
      lastName: parsedLastName,
      nickname: _nicknameController.text.trim(),
      currentActivity: _currentActivityController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      lineId: _lineIdController.text.trim(),
      travelDuration: _travelDurationController.text.trim(),
      subjects: List<String>.from(_selectedSubjects),
      profileImageBase64:
          _profileImageBase64 == null || _profileImageBase64!.isEmpty ? null : _profileImageBase64,
      teachingSchedule: () {
        final String serializedSchedule = _serializeScheduleBlocks();
        if (serializedSchedule.isNotEmpty) {
          return serializedSchedule;
        }
        if (_legacyScheduleNote != null && _legacyScheduleNote!.trim().isNotEmpty) {
          return _legacyScheduleNote!.trim();
        }
        return null;
      }(),
    );

    final String? error = await authProvider.updateTutor(
      originalEmail: currentTutor.email,
      updatedTutor: updatedTutor,
    );

    if (!mounted) {
      return;
    }

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
                          activeColor: const Color(0xFF880E4F),
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

  Future<void> _pickProfileImage() async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) {
        return;
      }
      final String encoded = base64Encode(await file.readAsBytes());
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageBase64 = encoded;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเลือกรูปได้: $error')),
      );
    }
  }

  void _removeProfileImage() {
    setState(() {
      _profileImageBase64 = '';
    });
  }

  Future<void> _showImageOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกรูปจากแกลเลอรี'),
                onTap: () {
                  Navigator.pop(context);
                  _pickProfileImage();
                },
              ),
              if (_profileImageBase64 != null && _profileImageBase64!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('ลบรูปโปรไฟล์'),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfileImage();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(Tutor tutor) {
    final String? imageData =
        _profileImageBase64 ?? tutor.profileImageBase64;
    final ImageProvider<Object>? imageProvider = _buildProfileImage(imageData);
    final String nicknameDisplay =
        _nicknameController.text.trim().isEmpty ? tutor.nickname : _nicknameController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: _showImageOptions,
          child: CircleAvatar(
            radius: 56,
            backgroundColor: Colors.transparent,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? const Icon(Icons.person, size: 58, color: Colors.grey)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        if (nicknameDisplay.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'ครู$nicknameDisplay',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF5C5C5C),
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
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
            _buildTextField(
              controller: _fullNameController,
              label: 'ชื่อจริง นามสกุล',
              icon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zก-๙\s]')),
              ],
              validator: (String? value) {
                final String trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'กรุณากรอกชื่อจริงและนามสกุล';
                }
                final List<String> parts = trimmed
                    .split(RegExp(r'\s+'))
                    .where((String part) => part.isNotEmpty)
                    .toList();
                if (parts.length < 2) {
                  return 'กรุณากรอกชื่อจริงและนามสกุล';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nicknameController,
              label: 'ชื่อเล่น',
              icon: Icons.person,
              textCapitalization: TextCapitalization.words,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zก-๙\s]')),
              ],
              validator: (String? value) =>
                  value == null || value.trim().isEmpty ? 'กรุณากรอกชื่อเล่น' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _lineIdController,
              label: 'ID LINE',
              icon: Icons.chat_bubble_outline,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty ? 'กรุณากรอก ID LINE' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'เบอร์โทรศัพท์',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty ? 'กรุณากรอกเบอร์โทรศัพท์' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _currentActivityController,
              label: 'สิ่งที่กำลังทำในปัจจุบัน (เช่น เรียน ป.ตรี คณะเทคนิคการแพทย์ที่มหิดล)',
              icon: Icons.work_outline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _travelDurationController,
              label: 'ระยะเวลาเดินทาง(เช่น 30 นาที)',
              icon: Icons.timer,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: null,
              alignLabelWithHint: true,
              validator: (String? value) =>
                  value == null || value.trim().isEmpty ? 'กรุณาระบุระยะเวลาเดินทาง' : null,
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
                        backgroundColor: const Color(0xFFFFCDD2),
                        labelStyle: const TextStyle(
                          color: Color(0xFF880E4F),
                          fontWeight: FontWeight.w600,
                        ),
                        deleteIconColor: const Color(0xFF880E4F),
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
            _buildScheduleGrid(),
            const SizedBox(height: 8),
            Text(
              'แตะหรือลากครอบช่วงเวลาเพื่อเพิ่มบล็อค และลากบล็อคเพื่อย้ายไปยังวันหรือเวลาอื่นได้',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (_legacyScheduleNote != null && _legacyScheduleNote!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'ข้อความจากตารางเดิม',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _legacyScheduleNote = null);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบข้อความเก่า'),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Text(
                  _legacyScheduleNote!,
                  style: const TextStyle(height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleGrid() {
    final double gridWidth = (_scheduleEndHour - _scheduleStartHour) * _scheduleHourWidth;
    final List<int> hourLabels =
        List<int>.generate(_scheduleEndHour - _scheduleStartHour, (int index) => _scheduleStartHour + index);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: _dayLabelWidth,
                child: const SizedBox.shrink(),
              ),
              SizedBox(
                width: gridWidth,
                child: Stack(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        ...hourLabels.map(
                          (int hour) => SizedBox(
                            width: _scheduleHourWidth,
                            child: Center(
                              child: Text(
                                _formatTimeLabel(hour),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        width: _scheduleHourWidth / 2,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatTimeLabel(_scheduleEndHour),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: List<Widget>.generate(
              _dayLabels.length,
              (int index) => _buildDayRow(index, gridWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(int dayIndex, double gridWidth) {
    final List<ScheduleBlock> dayBlocks = _scheduleBlocks
        .where((ScheduleBlock block) => block.dayIndex == dayIndex)
        .toList();
    dayBlocks.sort((ScheduleBlock a, ScheduleBlock b) => a.startSlot.compareTo(b.startSlot));
    return SizedBox(
      height: _scheduleRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _dayLabelWidth,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _dayLabels[dayIndex],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(
            width: gridWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) => _handleGridTap(dayIndex, details.localPosition.dx),
              onPanStart: (DragStartDetails details) =>
                  _startRangeSelection(dayIndex, details.localPosition.dx),
              onPanUpdate: (DragUpdateDetails details) =>
                  _updateRangeSelection(details.localPosition.dx),
              onPanEnd: (DragEndDetails details) =>
                  _finishRangeSelection(details: details),
              onPanCancel: () => _finishRangeSelection(cancelled: true),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScheduleGridPainter(
                        hourWidth: _scheduleHourWidth,
                        totalHours: _scheduleEndHour - _scheduleStartHour,
                      ),
                    ),
                  ),
                  if (_isRangeSelecting &&
                      _rangeSelectionDayIndex == dayIndex &&
                      _currentSelectionRange != null)
                    Positioned(
                      left: _currentSelectionRange!.startSlot * _slotWidth,
                      top: 6,
                      bottom: 6,
                      width: _currentSelectionRange!.durationSlots * _slotWidth,
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCDD2).withOpacity(0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFB71C1C).withOpacity(0.5),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final ScheduleBlock block in dayBlocks) _buildScheduleBlock(block),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBlock(ScheduleBlock block) {
    final double left = block.startSlot * _slotWidth;
    final double width = block.durationSlots * _slotWidth;
    final bool isTeaching = block.type == ScheduleBlockType.teaching;
    final Color backgroundColor = isTeaching ? const Color(0xFFFFE4E1) : Colors.grey.shade300;
    final Color textColor = isTeaching ? Colors.grey.shade700 : Colors.grey.shade800;
    final Color borderColor = isTeaching ? const Color(0xFFB71C1C) : Colors.grey.shade500;
    final String label = isTeaching
        ? (block.note != null && block.note!.isNotEmpty ? block.note! : 'สอน')
        : 'ไม่ว่าง';
    final bool isActive = _draggingBlockId == block.id;
    final bool isLifted = isActive && _isDragPrimed;
    final double topInset = isLifted ? 0 : 6;
    final double bottomInset = isLifted ? 12 : 6;
    return AnimatedPositioned(
      key: ValueKey<int>(block.id),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      left: left,
      top: topInset,
      bottom: bottomInset,
      width: width,
      child: GestureDetector(
        onTap: () => _onBlockTapped(block),
        onLongPressStart: (_) => _primeBlockDrag(block),
        onLongPressEnd: (_) => _endDraggingBlock(),
        onLongPressCancel: _endDraggingBlock,
        onPanStart: (_) => _startDraggingBlock(block),
        onPanUpdate: (DragUpdateDetails details) => _updateDraggingBlock(block, details.delta),
        onPanEnd: (_) => _endDraggingBlock(),
        child: Tooltip(
          message: '${_formatSlotRange(block.startSlot, block.durationSlots)}\n$label',
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: isLifted
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatSlotRange(block.startSlot, block.durationSlots),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withOpacity(0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

class _BlockDetails {
  const _BlockDetails({
    required this.dayIndex,
    required this.durationSlots,
    this.note,
  });

  final int dayIndex;
  final int durationSlots;
  final String? note;
}

class _SelectionRange {
  const _SelectionRange({required this.startSlot, required this.durationSlots});

  final int startSlot;
  final int durationSlots;
}

enum _BlockAction { edit, toggleType, delete }

class _ScheduleGridPainter extends CustomPainter {
  const _ScheduleGridPainter({
    required this.hourWidth,
    required this.totalHours,
  });

  final double hourWidth;
  final int totalHours;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint mainPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    final Paint halfPaint = Paint()
      ..color = const Color(0xFFF2F2F2)
      ..strokeWidth = 1;

    for (int hour = 0; hour <= totalHours; hour++) {
      final double x = hour * hourWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), mainPaint);
      if (hour < totalHours) {
        final double halfX = x + hourWidth / 2;
        canvas.drawLine(Offset(halfX, 0), Offset(halfX, size.height), halfPaint);
      }
    }
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), mainPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), mainPaint);
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridPainter oldDelegate) {
    return oldDelegate.hourWidth != hourWidth || oldDelegate.totalHours != totalHours;
  }
}
