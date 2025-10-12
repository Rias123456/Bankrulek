import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';


import 'package:flutter/gestures.dart';
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
    this.date,
    this.isRecurring = false,
  });

  final int id;
  final int dayIndex;
  final int startSlot;
  final int durationSlots;
  final ScheduleBlockType type;
  final String? note;
  final DateTime? date;
  final bool isRecurring;

  ScheduleBlock copyWith({
    int? id,
    int? dayIndex,
    int? startSlot,
    int? durationSlots,
    ScheduleBlockType? type,
    String? note,
    DateTime? date,
    bool? isRecurring,
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
      date: date ?? this.date,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'day': dayIndex,
      'start': startSlot,
      'duration': durationSlots,
      'type': type.name,
      'isRecurring': isRecurring,
      if (date != null) 'date': date!.toIso8601String(),
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
    return ScheduleBlock(
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
  // 🕐 ตัวแปรสำหรับระบบกดค้างเพื่อเลือกเวลา
  Timer? _longPressTimer;
  bool _isLongPressActive = false;

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
  final ScrollController _scheduleScrollController = ScrollController();
  ScrollHoldController? _scheduleHoldController;

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
  int? _rangeSelectionStartDayIndex;
  double? _rangeSelectionStartGlobalDy;
  _SelectionRange? _currentSelectionRange;
  bool _rangeSelectionMoved = false;
  bool _rangeSelectionPrimed = false;
  DateTime? _rangeSelectionSelectedDate;
  int? _pendingRangeDayIndex;
  Offset? _pendingRangeLocalOffset;
  Offset? _pendingRangeGlobalOffset;
  bool _canScrollBackward = false;
  bool _canScrollForward = false;
  late DateTime _weekStartDate;

  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 7;
  static const int _scheduleEndHour = 21;
  static const int _minutesPerSlot = 30;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 72;
  static const double _dayLabelWidth = 96;
  static const double _rangeSelectionActivationThreshold = 8;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  int get _slotsPerHour => math.max(1, 60 ~/ _minutesPerSlot);

  int get _totalSlots => (_scheduleEndHour - _scheduleStartHour) * _slotsPerHour;

  double get _slotWidth => _scheduleHourWidth / _slotsPerHour;

  List<DateTime> get _currentWeekDates => List<DateTime>.generate(
        _dayLabels.length,
        (int index) => DateTime(
          _weekStartDate.year,
          _weekStartDate.month,
          _weekStartDate.day,
        ).add(Duration(days: index)),
      );

  DateTime _normalizeDate(DateTime input) => DateTime(input.year, input.month, input.day);

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _dayIndexForWeekday(int weekday) => (weekday - DateTime.saturday + 7) % 7;

  int _dayIndexForDate(DateTime date) => _dayIndexForWeekday(date.weekday);

  int _resolvedDayIndex(ScheduleBlock block) {
    if (block.date != null) {
      return _dayIndexForDate(block.date!);
    }
    return block.dayIndex;
  }

  DateTime _sortAnchorForBlock(ScheduleBlock block) {
    final DateTime baseDate = block.date != null
        ? _normalizeDate(block.date!)
        : _pseudoDateForDayIndex(_resolvedDayIndex(block));
    return baseDate.add(Duration(minutes: block.startSlot * _minutesPerSlot));
  }

  DateTime _pseudoDateForDayIndex(int dayIndex) =>
      DateTime(1970, 1, 1 + _clampInt(dayIndex, 0, _dayLabels.length - 1));

  DateTime _displayDateForBlock(ScheduleBlock block) {
    if (block.date != null && !block.isRecurring) {
      return _normalizeDate(block.date!);
    }
    final int index = _clampInt(_resolvedDayIndex(block), 0, _dayLabels.length - 1);
    return _currentWeekDates[index];
  }

  DateTime _calculateWeekStart(DateTime anchor) {
    final DateTime normalized = DateTime(anchor.year, anchor.month, anchor.day);
    final int offset = (normalized.weekday - DateTime.saturday + 7) % 7;
    return normalized.subtract(Duration(days: offset));
  }

  String _formatDateLabel(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _formatWeekRangeLabel() {
    final List<DateTime> dates = _currentWeekDates;
    if (dates.isEmpty) {
      return '';
    }
    final String start = _formatDateLabel(dates.first);
    final String end = _formatDateLabel(dates.last);
    if (start == end) {
      return start;
    }
    return '$start - $end';
  }

  String _formatDayWithDate(int dayIndex) {
    final int safeIndex = _clampInt(dayIndex, 0, _dayLabels.length - 1);
    final DateTime date = _currentWeekDates[safeIndex];
    return '${_dayLabels[safeIndex]} ${_formatDateLabel(date)}';
  }

  String _formatDayWithDateFromDate(DateTime date) {
    final int index = _dayIndexForDate(date);
    return '${_dayLabels[_clampInt(index, 0, _dayLabels.length - 1)]} ${_formatDateLabel(date)}';
  }

  DateTime _blockStartDateTime(DateTime dayDate, int startSlot) {
    final DateTime normalized = _normalizeDate(dayDate);
    return DateTime(normalized.year, normalized.month, normalized.day, _scheduleStartHour)
        .add(Duration(minutes: startSlot * _minutesPerSlot));
  }

  DateTime _blockEndDateTime(DateTime dayDate, int startSlot, int durationSlots) {
    return _blockStartDateTime(dayDate, startSlot)
        .add(Duration(minutes: durationSlots * _minutesPerSlot));
  }

  @override
  void initState() {
    _weekStartDate = _calculateWeekStart(DateTime.now());
    super.initState();
    _scheduleScrollController.addListener(_handleScheduleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScheduleScrollChanged());
  }

  @override
  void dispose() {
    _scheduleScrollController.removeListener(_handleScheduleScrollChanged);
    _fullNameController.dispose();
    _nicknameController.dispose();
    _lineIdController.dispose();
    _phoneController.dispose();
    _currentActivityController.dispose();
    _travelDurationController.dispose();
    _releaseScheduleHold();
    _scheduleScrollController.dispose();
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
        final int sourceMinutesPerSlot = (data['minutesPerSlot'] is int && (data['minutesPerSlot'] as int) > 0)
            ? data['minutesPerSlot'] as int
            : 30;
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
          final int startSlotMinutes = parsed.startSlot * sourceMinutesPerSlot;
          final int durationMinutes = parsed.durationSlots * sourceMinutesPerSlot;
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
            date: parsed.date != null ? _normalizeDate(parsed.date!) : null,
          );
          final DateTime placementDay = sanitized.date != null
              ? _normalizeDate(sanitized.date!)
              : _pseudoDateForDayIndex(sanitized.dayIndex);
          if (_canPlaceBlock(placementDay, sanitized.startSlot, sanitized.durationSlots, existing: parsedBlocks)) {
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
      'minutesPerSlot': _minutesPerSlot,
      'blocks': _scheduleBlocks.map((ScheduleBlock block) => block.toJson()).toList(),
    };
    return '$_scheduleSerializationPrefix${jsonEncode(data)}';
  }

  void _sortBlocks() {
    _scheduleBlocks.sort((ScheduleBlock a, ScheduleBlock b) {
      final DateTime anchorA = _sortAnchorForBlock(a);
      final DateTime anchorB = _sortAnchorForBlock(b);
      final int anchorCompare = anchorA.compareTo(anchorB);
      if (anchorCompare != 0) {
        return anchorCompare;
      }
      final int dayCompare = _resolvedDayIndex(a).compareTo(_resolvedDayIndex(b));
      if (dayCompare != 0) {
        return dayCompare;
      }
      if (a.isRecurring != b.isRecurring) {
        return a.isRecurring ? 1 : -1;
      }
      return a.startSlot.compareTo(b.startSlot);
    });
  }

  void _handleScrollHoldCanceled() {
    _scheduleHoldController = null;
  }

  void _handleScheduleScrollChanged() {
    if (!_scheduleScrollController.hasClients || !mounted) {
      return;
    }
    final ScrollPosition position = _scheduleScrollController.position;
    final bool canGoBackward =
        position.pixels > position.minScrollExtent + 1.0 && position.maxScrollExtent > position.minScrollExtent;
    final bool canGoForward =
        position.pixels < position.maxScrollExtent - 1.0 && position.maxScrollExtent > position.minScrollExtent;
    if (canGoBackward != _canScrollBackward || canGoForward != _canScrollForward) {
      setState(() {
        _canScrollBackward = canGoBackward;
        _canScrollForward = canGoForward;
      });
    }
  }

  void _shiftWeek(int days) {
    if (days == 0) {
      return;
    }
    setState(() {
      _weekStartDate = _weekStartDate.add(Duration(days: days));
    });
  }

  Future<void> _pickWeekStartDate() async {
    final DateTime initialDate = _weekStartDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _weekStartDate = _calculateWeekStart(picked);
    });
  }

  Future<void> _scrollScheduleBy(double delta) async {
    if (!_scheduleScrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scheduleScrollController.position;
    final double target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) {
      return;
    }
    await _scheduleScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _acquireScheduleHold() {
    if (_scheduleHoldController != null || !_scheduleScrollController.hasClients) {
      return;
    }
    _scheduleHoldController =
        _scheduleScrollController.position.hold(_handleScrollHoldCanceled);
  }

  void _releaseScheduleHold() {
    _scheduleHoldController?.cancel();
    _scheduleHoldController = null;
  }

  void _clearPendingRangeSelection() {
    _pendingRangeDayIndex = null;
    _pendingRangeLocalOffset = null;
    _pendingRangeGlobalOffset = null;
    _rangeSelectionPrimed = false;
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
    DateTime dayDate,
    int startSlot,
    int durationSlots, {
    int? ignoreId,
    List<ScheduleBlock>? existing,
  }) {
    if (startSlot < 0 || durationSlots <= 0 || startSlot + durationSlots > _totalSlots) {
      return false;
    }
    final DateTime normalizedDay = _normalizeDate(dayDate);
    final int dayIndex = _dayIndexForDate(normalizedDay);
    final List<ScheduleBlock> source = existing ?? _scheduleBlocks;
    for (final ScheduleBlock block in source) {
      if (ignoreId != null && block.id == ignoreId) {
        continue;
      }
      if (!_blockOccursOnDate(block, normalizedDay, dayIndex)) {
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

  bool _blockOccursOnDate(ScheduleBlock block, DateTime dayDate, int dayIndex) {
    if (block.isRecurring) {
      final int recurringDay = block.date != null ? _dayIndexForDate(block.date!) : block.dayIndex;
      return recurringDay == dayIndex;
    }
    if (block.date != null) {
      return _isSameDate(_normalizeDate(block.date!), dayDate);
    }
    return block.dayIndex == dayIndex;
  }

  int _calculateMaxDuration(DateTime dayDate, int startSlot, int? ignoreId) {
    final int maxSlots = _totalSlots - startSlot;
    if (maxSlots <= 0) {
      return 0;
    }
    final DateTime normalizedDay = _normalizeDate(dayDate);
    final int dayIndex = _dayIndexForDate(normalizedDay);
    final List<ScheduleBlock> dayBlocks = _scheduleBlocks
        .where(
          (ScheduleBlock block) =>
              (ignoreId == null || block.id != ignoreId) && _blockOccursOnDate(block, normalizedDay, dayIndex),
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
    final int minutes = slots * _minutesPerSlot;
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

  String _formatSlotRange(DateTime dayDate, int startSlot, int durationSlots) {
    final DateTime start = _blockStartDateTime(dayDate, startSlot);
    final DateTime end = _blockEndDateTime(dayDate, startSlot, durationSlots);
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
    final DateTime dayDate = _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];
    if (!_canPlaceBlock(dayDate, anchorSlot, 1)) {
      return _SelectionRange(startSlot: anchorSlot, durationSlots: 1);
    }
    if (normalizedTarget >= anchorSlot) {
      while (end > anchorSlot && !_canPlaceBlock(dayDate, start, end - start + 1)) {
        end -= 1;
      }
      if (!_canPlaceBlock(dayDate, start, end - start + 1)) {
        start = anchorSlot;
        end = anchorSlot;
      }
    } else {
      while (start < anchorSlot && !_canPlaceBlock(dayDate, start, end - start + 1)) {
        start += 1;
      }
      if (!_canPlaceBlock(dayDate, start, end - start + 1)) {
        start = anchorSlot;
        end = anchorSlot;
      }
    }
    return _SelectionRange(startSlot: start, durationSlots: end - start + 1);
  }

  void _handleRangePanDown(int dayIndex, DragDownDetails details) {
    _acquireScheduleHold();
    _pendingRangeDayIndex = dayIndex;
    _pendingRangeLocalOffset = details.localPosition;
    _pendingRangeGlobalOffset = details.globalPosition;
    _rangeSelectionPrimed = true;
  }

  void _handleRangePanStart(int dayIndex, DragStartDetails details) {
    _acquireScheduleHold();
    _pendingRangeDayIndex ??= dayIndex;
    _pendingRangeLocalOffset ??= details.localPosition;
    _pendingRangeGlobalOffset ??= details.globalPosition;
  }

  void _handleRangePanUpdate(int dayIndex, DragUpdateDetails details) {
    if (_isRangeSelecting) {
      _updateRangeSelection(details);
      return;
    }
    if (!_rangeSelectionPrimed ||
        _pendingRangeDayIndex == null ||
        _pendingRangeLocalOffset == null ||
        _pendingRangeGlobalOffset == null) {
      return;
    }
    final Offset delta = details.globalPosition - _pendingRangeGlobalOffset!;
    if (delta.distanceSquared <
        _rangeSelectionActivationThreshold * _rangeSelectionActivationThreshold) {
      return;
    }
    _startRangeSelection(
      _pendingRangeDayIndex!,
      _pendingRangeLocalOffset!,
      _pendingRangeGlobalOffset!,
    );
    if (_isRangeSelecting) {
      _updateRangeSelection(details);
    }
  }

  void _handleRangePanEnd(DragEndDetails details) {
  // 🧠 debug log ตรวจ flow ว่ามันมาจริงไหม
  debugPrint('🟢 handleRangePanEnd | moved=$_rangeSelectionMoved | selecting=$_isRangeSelecting');

  // ✅ ถ้ายังอยู่ในโหมดเลือก ให้ถือว่า "เลือกสำเร็จ"
  // ❌ ไม่ต้องเช็ก _rangeSelectionMoved เพราะบางทีลากสั้นก็ถือว่าเลือกแล้ว
  final bool shouldCancel = !_isRangeSelecting;

  // ✅ ส่งไปปิดโหมดและเปิด modal ต่อ
  _finishRangeSelection(details: details, cancelled: shouldCancel);
}

  void _handleRangePanCancel() {
    _finishRangeSelection(cancelled: true);
  }

void _startRangeSelection(int dayIndex, Offset localPosition, Offset globalPosition) {
  if (_isRangeSelecting) return;

  final int slot = _slotFromDx(localPosition.dx);
  final DateTime dayDate = _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];
  if (!_canPlaceBlock(dayDate, slot, 1)) {
    _cancelRangeSelection();
    return;
  }

  // ✅ ย้ายมาลบ pending ก่อน แล้วค่อย setState
  _clearPendingRangeSelection();

  setState(() {
    _isRangeSelecting = true;
    _rangeSelectionDayIndex = dayIndex;
    _rangeSelectionStartDayIndex = dayIndex;
    _rangeSelectionAnchorSlot = slot;
    _rangeSelectionStartGlobalDy = globalPosition.dy;
    _currentSelectionRange = _SelectionRange(startSlot: slot, durationSlots: 1);
    _rangeSelectionMoved = false;
    _rangeSelectionSelectedDate = dayDate;
    _rangeSelectionPrimed = true; // ✅ ตั้งให้แน่ชัด
  });
}


  void _updateRangeSelection(DragUpdateDetails details) {
    if (!_isRangeSelecting ||
        _rangeSelectionDayIndex == null ||
        _rangeSelectionAnchorSlot == null ||
        _rangeSelectionStartDayIndex == null ||
        _rangeSelectionStartGlobalDy == null) {
      return;
    }
    final int targetSlot = _slotFromDx(details.localPosition.dx);
    final int anchor = _rangeSelectionAnchorSlot!;
    final double verticalDelta = details.globalPosition.dy - _rangeSelectionStartGlobalDy!;
    final int dayOffset = verticalDelta ~/ _scheduleRowHeight;
    final int targetDay =
        _clampInt(_rangeSelectionStartDayIndex! + dayOffset, 0, _dayLabels.length - 1);
    final DateTime targetDayDate = _currentWeekDates[targetDay];
    final _SelectionRange resolved = _resolveSelectionRange(targetDay, anchor, targetSlot);
    final bool moved = targetSlot != anchor || targetDay != _rangeSelectionDayIndex;
    if (_currentSelectionRange?.startSlot != resolved.startSlot ||
        _currentSelectionRange?.durationSlots != resolved.durationSlots) {
      setState(() {
        _currentSelectionRange = resolved;
        _rangeSelectionDayIndex = targetDay;
        _rangeSelectionMoved = _rangeSelectionMoved || moved;
        _rangeSelectionSelectedDate = targetDayDate;
      });
    } else if (moved && !_rangeSelectionMoved) {
      setState(() {
        _rangeSelectionDayIndex = targetDay;
        _rangeSelectionMoved = true;
        _rangeSelectionSelectedDate = targetDayDate;
      });
    } else if (_rangeSelectionDayIndex != targetDay) {
      setState(() {
        _rangeSelectionDayIndex = targetDay;
        _rangeSelectionSelectedDate = targetDayDate;
      });
    }
  }

 /// ฟังก์ชัน: จบการเลือกช่วงเวลา แล้วเปิด modal ให้เลือกประเภท block
/// ✅ ฟังก์ชัน: จบการเลือกช่วงเวลา แล้วเปิด modal ให้เลือกประเภท block
Future<void> _finishRangeSelection({DragEndDetails? details, bool cancelled = false}) async {
  debugPrint('🟢 finishRangeSelection | cancelled=$cancelled | primed=$_rangeSelectionPrimed | selecting=$_isRangeSelecting');

  if (!_rangeSelectionPrimed || cancelled || !_isRangeSelecting || _currentSelectionRange == null) {
    setState(() {
      _isRangeSelecting = false;
      _rangeSelectionPrimed = false;
      _currentSelectionRange = null;
    });
    _clearPendingRangeSelection();
    return;
  }

  final int dayIndex = _rangeSelectionDayIndex ?? 0;
  final int startSlot = _currentSelectionRange!.startSlot;
  final int durationSlots = _currentSelectionRange!.durationSlots;

  setState(() {
    _isRangeSelecting = false;
    _rangeSelectionPrimed = false;
  });
  _clearPendingRangeSelection();

  // ✅ ปิด focus ป้องกัน modal ซ้อน
  FocusManager.instance.primaryFocus?.unfocus();
  await Future.delayed(const Duration(milliseconds: 150));

  // ✅ เปิด modal เลือกประเภท block (สอน / ไม่ว่าง)
  final ScheduleBlockType? type = await _showBlockTypeChooser();
  if (!mounted || type == null) {
    debugPrint('🚫 ยกเลิกเลือกประเภท block');
    return;
  }

  await Future.delayed(const Duration(milliseconds: 250));

  // ✅ เปิด modal เก็บรายละเอียดบล็อก
  final _BlockDetails? detailsResult = await _collectBlockDetails(
    type: type,
    dayIndex: dayIndex,
    dayDate: _currentWeekDates[dayIndex],
    startSlot: startSlot,
    initialDuration: durationSlots,
  );

  if (!mounted || detailsResult == null) {
    debugPrint('🚫 ไม่มีรายละเอียด block');
    return;
  }

  // ✅ ตรวจสอบว่าช่วงเวลาว่างไหม
  if (!_canPlaceBlock(detailsResult.dayDate, startSlot, detailsResult.durationSlots)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
    );
    return;
  }

  // ✅ สร้างบล็อกใหม่
  final ScheduleBlock newBlock = ScheduleBlock(
    id: _nextBlockId++,
    dayIndex: detailsResult.dayIndex,
    startSlot: startSlot,
    durationSlots: detailsResult.durationSlots,
    type: type,
    note: type == ScheduleBlockType.teaching ? detailsResult.note : null,
    date: _normalizeDate(detailsResult.dayDate),
    isRecurring: detailsResult.isRecurring,
  );

  setState(() {
    _scheduleBlocks = [..._scheduleBlocks, newBlock];
    _legacyScheduleNote = null;
    _sortBlocks();
  });

  debugPrint('✅ เพิ่ม block ใหม่เรียบร้อย: day=$dayIndex slot=$startSlot dur=$durationSlots type=$type');
}



  void _cancelRangeSelection() {
    if (!_isRangeSelecting && _currentSelectionRange == null) {
      _releaseScheduleHold();
      _clearPendingRangeSelection();
      _rangeSelectionMoved = false;
      _rangeSelectionSelectedDate = null;
      return;
    }
    setState(() {
      _isRangeSelecting = false;
      _rangeSelectionDayIndex = null;
      _rangeSelectionAnchorSlot = null;
      _rangeSelectionStartDayIndex = null;
      _rangeSelectionStartGlobalDy = null;
      _currentSelectionRange = null;
      _rangeSelectionMoved = false;
      _rangeSelectionSelectedDate = null;
    });
    _releaseScheduleHold();
    _clearPendingRangeSelection();
  }

  Future<void> _handleGridTap(int dayIndex, double dx) async {
    final int slot = _slotFromDx(dx);
    final DateTime dayDate = _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];
    if (!_canPlaceBlock(dayDate, slot, 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final int maxDuration = _calculateMaxDuration(dayDate, slot, null);
    if (maxDuration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final ScheduleBlockType? type = await _showBlockTypeChooser();
    if (!mounted) {
      return;
    }
    if (type == null) {
      return;
    }
    final _BlockDetails? details = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      dayDate: dayDate,
      startSlot: slot,
    );
    if (!mounted) {
      return;
    }
    if (details == null) {
      return;
    }
    if (!_canPlaceBlock(details.dayDate, slot, details.durationSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }
    final ScheduleBlock newBlock = ScheduleBlock(
      id: _nextBlockId++,
      dayIndex: _dayIndexForDate(details.dayDate),
      startSlot: slot,
      durationSlots: details.durationSlots,
      type: type,
      note: type == ScheduleBlockType.teaching ? details.note : null,
      date: _normalizeDate(details.dayDate),
      isRecurring: details.isRecurring,
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
                  textColor: Colors.grey.shade600,
                  title: 'สอน',
                  subtitle: '',
                  onTap: () => Navigator.pop(context, ScheduleBlockType.teaching),
                ),
                const SizedBox(height: 12),
                _buildBlockOption(
                  color: Colors.grey.shade300,
                  borderColor: Colors.grey.shade500,
                  textColor: Colors.grey.shade700,
                  title: 'ไม่ว่าง',
                  subtitle: '',
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
    required DateTime dayDate,
    required int startSlot,
    int? initialDuration,
    String? initialNote,
    int? ignoreBlockId,
    bool initialRecurring = false,
  }) async {
    final List<DateTime> weekDates = _currentWeekDates;
    final List<int> maxDurationPerDay = List<int>.generate(
      weekDates.length,
      (int index) => _calculateMaxDuration(weekDates[index], startSlot, ignoreBlockId),
    );
    if (maxDurationPerDay.every((int value) => value <= 0)) {
      return null;
    }

    int selectedDay = _clampInt(dayIndex, 0, weekDates.length - 1);
    DateTime selectedDate = _normalizeDate(dayDate);
    if (maxDurationPerDay[selectedDay] <= 0) {
      final int fallbackIndex = maxDurationPerDay.indexWhere((int value) => value > 0);
      if (fallbackIndex == -1) {
        return null;
      }
      selectedDay = fallbackIndex;
      selectedDate = weekDates[fallbackIndex];
    }

    int maxForSelectedDay = math.max(1, maxDurationPerDay[selectedDay]);
    int duration = initialDuration != null
        ? _clampInt(initialDuration, 1, maxForSelectedDay)
        : math.min(
            type == ScheduleBlockType.teaching ? math.min(2, maxForSelectedDay) : 1,
            maxForSelectedDay,
          );
    bool isRecurring = initialRecurring;
    final TextEditingController noteController = TextEditingController(text: initialNote ?? '');

    final _BlockDetails? result = await showModalBottomSheet<_BlockDetails>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool isTeaching = type == ScheduleBlockType.teaching;
            final double bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: bottomPadding + 16,
                ),
                child: SingleChildScrollView(
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
                        isTeaching ? 'เพิ่มช่วงเวลาสอน' : 'ทำเครื่องหมายไม่ว่าง',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatDayWithDateFromDate(selectedDate)} ${_formatSlotRange(selectedDate, startSlot, duration)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedDay,
                        decoration: const InputDecoration(labelText: 'วัน'),
                        items: List<DropdownMenuItem<int>>.generate(
                          weekDates.length,
                          (int index) {
                            final bool enabled = maxDurationPerDay[index] > 0;
                            final DateTime optionDate = weekDates[index];
                            return DropdownMenuItem<int>(
                              value: index,
                              enabled: enabled,
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(_formatDayWithDateFromDate(optionDate))),
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
                            selectedDate = weekDates[value];
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
                          maxLines: null,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: isRecurring,
                          onChanged: (bool value) => setState(() => isRecurring = value),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('สอนประจำทุกสัปดาห์'),
                          subtitle: const Text('ทำซ้ำในวันและเวลาเดียวกันของทุกสัปดาห์'),
                        ),
                        const SizedBox(height: 12),
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
                        '',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ยกเลิก'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              if (!_canPlaceBlock(selectedDate, startSlot, duration, ignoreId: ignoreBlockId)) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
                                );
                                return;
                              }
                              Navigator.pop(
                                context,
                                _BlockDetails(
                                  dayIndex: selectedDay,
                                  dayDate: selectedDate,
                                  durationSlots: duration,
                                  note: isTeaching
                                      ? (noteController.text.trim().isEmpty
                                          ? null
                                          : noteController.text.trim())
                                      : null,
                                  isRecurring: isTeaching ? isRecurring : false,
                                ),
                              );
                            },
                            child: const Text('ยืนยัน'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
    final int baseDayIndex = _resolvedDayIndex(block);
    final int newDay = _clampInt(baseDayIndex + verticalSteps, 0, _dayLabels.length - 1);
    final DateTime newDayDate = _currentWeekDates[newDay];
    final int newStart = _clampInt(block.startSlot + horizontalSteps, 0, _totalSlots - block.durationSlots);
    if (!_canPlaceBlock(newDayDate, newStart, block.durationSlots, ignoreId: block.id)) {
      return;
    }

    setState(() {
      _scheduleBlocks = _scheduleBlocks
          .map(
            (ScheduleBlock current) => current.id == block.id
                ? current.copyWith(
                    dayIndex: newDay,
                    startSlot: newStart,
                    date: _normalizeDate(newDayDate),
                  )
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
    final DateTime blockDisplayDate = _displayDateForBlock(block);
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
                  '${_formatDayWithDateFromDate(blockDisplayDate)} ${_formatSlotRange(blockDisplayDate, block.startSlot, block.durationSlots)}',
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

    if (!mounted) {
      return;
    }

    if (action == null) {
      return;
    }

    switch (action) {
      case _BlockAction.edit:
        final _BlockDetails? details = await _collectBlockDetails(
          type: block.type,
          dayIndex: _dayIndexForDate(blockDisplayDate),
          dayDate: blockDisplayDate,
          startSlot: block.startSlot,
          initialDuration: block.durationSlots,
          initialNote: block.note,
          ignoreBlockId: block.id,
          initialRecurring: block.isRecurring,
        );
        if (!mounted) {
          return;
        }
        if (details != null) {
          if (!_canPlaceBlock(details.dayDate, block.startSlot, details.durationSlots, ignoreId: block.id)) {
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
                          dayIndex: _dayIndexForDate(details.dayDate),
                          startSlot: block.startSlot,
                          durationSlots: details.durationSlots,
                          note: block.type == ScheduleBlockType.teaching ? details.note : null,
                          date: _normalizeDate(details.dayDate),
                          isRecurring: block.type == ScheduleBlockType.teaching ? details.isRecurring : false,
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
                      ? current.copyWith(
                          type: ScheduleBlockType.unavailable,
                          clearNote: true,
                          isRecurring: false,
                        )
                      : current,
                )
                .toList();
          });
        } else {
          final _BlockDetails? details = await _collectBlockDetails(
            type: ScheduleBlockType.teaching,
            dayIndex: _dayIndexForDate(blockDisplayDate),
            dayDate: blockDisplayDate,
            startSlot: block.startSlot,
            initialDuration: block.durationSlots,
            ignoreBlockId: block.id,
          );
          if (!mounted) {
            return;
          }
          if (details != null) {
            if (!_canPlaceBlock(details.dayDate, block.startSlot, details.durationSlots, ignoreId: block.id)) {
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
                            dayIndex: _dayIndexForDate(details.dayDate),
                            startSlot: block.startSlot,
                            type: ScheduleBlockType.teaching,
                            durationSlots: details.durationSlots,
                            note: details.note,
                            date: _normalizeDate(details.dayDate),
                            isRecurring: details.isRecurring,
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
  label: 'ระยะเวลาเดินทาง (เช่น 30 นาที)',
  icon: Icons.timer,
  keyboardType: TextInputType.multiline,
  textCapitalization: TextCapitalization.sentences,
  textInputAction: TextInputAction.newline,
  minLines: 1,
  maxLines: null,
  alignLabelWithHint: true,
  // ❌ เอา validator ออก หรือใช้ null แทน
  validator: (_) => null,
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
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => _shiftWeek(-7),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'สัปดาห์ก่อนหน้า',
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickWeekStartDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      _formatWeekRangeLabel(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftWeek(7),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'สัปดาห์ถัดไป',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildScheduleGrid(),
            const SizedBox(height: 8),
            Text(
              '',
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
  final double scrollStep = _scheduleHourWidth * 2;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              'เลื่อนตารางเวลา',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            IconButton(
              onPressed: _canScrollBackward ? () => _scrollScheduleBy(-scrollStep) : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: 'เลื่อนไปช่วงเวลาก่อนหน้า',
            ),
            IconButton(
              onPressed: _canScrollForward ? () => _scrollScheduleBy(scrollStep) : null,
              icon: const Icon(Icons.chevron_right),
              tooltip: 'เลื่อนไปช่วงเวลาถัดไป',
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),

      // ✅ แก้ตรงนี้
      ClipRect(
        child: GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (!_scheduleScrollController.hasClients) return;
            final double delta = -details.delta.dx;
            final double newOffset = (_scheduleScrollController.offset + delta).clamp(
              _scheduleScrollController.position.minScrollExtent,
              _scheduleScrollController.position.maxScrollExtent,
            );
            _scheduleScrollController.jumpTo(newOffset);
          },
          child: SingleChildScrollView(
            controller: _scheduleScrollController,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(width: _dayLabelWidth, child: const SizedBox.shrink()),
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
          ),
        ), // <-- ปิด GestureDetector
      ),   // <-- ปิด ClipRect
    ],
  );
}


  Widget _buildDayRow(int dayIndex, double gridWidth) {
    final int safeDayIndex = _clampInt(dayIndex, 0, _dayLabels.length - 1);
    final DateTime dayDate = _currentWeekDates[safeDayIndex];
    final List<ScheduleBlock> dayBlocks = _scheduleBlocks
        .where(
          (ScheduleBlock block) =>
              _blockOccursOnDate(block, _normalizeDate(dayDate), safeDayIndex),
        )
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
                '${_dayLabels[safeDayIndex]}\n${_formatDateLabel(dayDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
              ),
            ),
          ),
          SizedBox(
           width: gridWidth,
child: RawGestureDetector(
  gestures: {
    LongPressGestureRecognizer:
        GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
      () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 200)),
      (LongPressGestureRecognizer instance) {
        instance
          ..onLongPressStart = (details) {
            debugPrint('🕐 กดค้างเริ่ม (0.5วิ) | day=$dayIndex');
            _isRangeSelecting = true;

            final int slot = _slotFromDx(details.localPosition.dx);
            final DateTime dayDate = _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];

            setState(() {
              _rangeSelectionDayIndex = dayIndex;
              _rangeSelectionAnchorSlot = slot;
              _currentSelectionRange = _SelectionRange(startSlot: slot, durationSlots: 1);
              _rangeSelectionSelectedDate = dayDate;
            });

            HapticFeedback.mediumImpact();
          }
          ..onLongPressMoveUpdate = (details) {
            if (!_isRangeSelecting || _rangeSelectionAnchorSlot == null) return;

            final int targetSlot = _slotFromDx(details.localPosition.dx);
            final int anchor = _rangeSelectionAnchorSlot!;
            final int start = math.min(anchor, targetSlot);
            final int duration = (anchor - targetSlot).abs() + 1;

            setState(() {
              _currentSelectionRange =
                  _SelectionRange(startSlot: start, durationSlots: duration);
            });
          }
          ..onLongPressEnd = (details) async {
            if (!_isRangeSelecting || _currentSelectionRange == null) return;

            final int dayIndexFinal = _rangeSelectionDayIndex ?? dayIndex;
            final int startSlot = _currentSelectionRange!.startSlot;
            final int durationSlots = _currentSelectionRange!.durationSlots;

            setState(() {
              _isRangeSelecting = false;
            });

            final ScheduleBlockType? type = await _showBlockTypeChooser();
            if (type == null) return;

            final _BlockDetails? detailsResult = await _collectBlockDetails(
              type: type,
              dayIndex: dayIndexFinal,
              dayDate: _currentWeekDates[dayIndexFinal],
              startSlot: startSlot,
              initialDuration: durationSlots,
            );

            if (detailsResult == null) return;

            final ScheduleBlock newBlock = ScheduleBlock(
              id: _nextBlockId++,
              dayIndex: dayIndexFinal,
              startSlot: startSlot,
              durationSlots: detailsResult.durationSlots,
              type: type,
              note: type == ScheduleBlockType.teaching ? detailsResult.note : null,
              date: _normalizeDate(detailsResult.dayDate),
              isRecurring: detailsResult.isRecurring,
            );

            setState(() {
              _scheduleBlocks = [..._scheduleBlocks, newBlock];
              _sortBlocks();
            });

            debugPrint('✅ เพิ่ม block สำเร็จ slot=$startSlot dur=$durationSlots');
          }
          ..onLongPressCancel = () {
            debugPrint('🚫 ยกเลิก long press');
            setState(() => _isRangeSelecting = false);
          };
      },
    ),
  },
  behavior: HitTestBehavior.opaque,
  child: Stack(
    children: [
      Positioned.fill(
        child: CustomPaint(
          painter: _ScheduleGridPainter(
            hourWidth: _scheduleHourWidth,
            totalHours: _scheduleEndHour - _scheduleStartHour,
            slotsPerHour: _slotsPerHour,
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
                color: Colors.grey.shade300.withOpacity(0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade500),
              ),
            ),
          ),
        ),
      for (final ScheduleBlock block in dayBlocks)
        _buildScheduleBlock(block, dayDate),
    ],
  ),
),

          ),
        ],
      ),
    );
  }

  Widget _buildScheduleBlock(ScheduleBlock block, DateTime dayDate) {
    final double left = block.startSlot * _slotWidth;
    final double width = block.durationSlots * _slotWidth;
    final bool isTeaching = block.type == ScheduleBlockType.teaching;
    final Color backgroundColor = isTeaching ? const Color(0xFFFFE4E1) : Colors.grey.shade300;
    final Color textColor = isTeaching ? Colors.grey.shade700 : Colors.grey.shade800;
    final Color borderColor = isTeaching ? const Color(0xFFB71C1C) : Colors.grey.shade500;
    final String label = isTeaching
        ? (block.note != null && block.note!.isNotEmpty ? block.note! : 'สอน')
        : 'ไม่ว่าง';
    final bool isRecurring = block.isRecurring && isTeaching;
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
          message:
              '${_formatDayWithDateFromDate(dayDate)} ${_formatSlotRange(dayDate, block.startSlot, block.durationSlots)}\n$label',
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
    // 🕒 เวลา + badge "ประจำ" อยู่บรรทัดเดียวกัน
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatSlotRange(dayDate, block.startSlot, block.durationSlots),
          style: TextStyle(
            fontSize: 11,
            color: textColor.withOpacity(0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (isRecurring)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'ประจำ',
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
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
    required this.dayDate,
    required this.durationSlots,
    this.note,
    this.isRecurring = false,
  });

  final int dayIndex;
  final DateTime dayDate;
  final int durationSlots;
  final String? note;
  final bool isRecurring;
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
    required this.slotsPerHour,
  });

  final double hourWidth;
  final int totalHours;
  final int slotsPerHour;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint mainPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    final Paint divisionPaint = Paint()
      ..color = const Color(0xFFF2F2F2)
      ..strokeWidth = 1;

    for (int hour = 0; hour <= totalHours; hour++) {
      final double x = hour * hourWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), mainPaint);
      if (hour < totalHours && slotsPerHour > 1) {
        for (int slot = 1; slot < slotsPerHour; slot++) {
          final double slotX = x + hourWidth * slot / slotsPerHour;
          canvas.drawLine(Offset(slotX, 0), Offset(slotX, size.height), divisionPaint);
        }
      }
    }
    canvas.drawLine(Offset(0, 0), Offset(size.width, 0), mainPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), mainPaint);
  }

  @override
  bool shouldRepaint(covariant _ScheduleGridPainter oldDelegate) {
    return oldDelegate.hourWidth != hourWidth ||
        oldDelegate.totalHours != totalHours ||
        oldDelegate.slotsPerHour != slotsPerHour;
  }
}
