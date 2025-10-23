import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/tutor_service.dart';
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
  final List<GlobalKey> _dayStackKeys =
      List<GlobalKey>.generate(_dayLabels.length, (_) => GlobalKey());

  List<String> _selectedSubjects = <String>[];
  String? _profileImageBase64;
  final ImagePicker _imagePicker = ImagePicker();
  final TutorService _tutorService = TutorService();
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  String? _tutorId;
  String? _email;
  String? _password;
  String? _photoUrl;
  Uint8List? _newProfileImageBytes;
  bool _removeExistingPhoto = false;
  Map<String, dynamic>? _tutorDocumentData;
  List<ScheduleBlock> _scheduleBlocks = <ScheduleBlock>[];
  int _nextBlockId = 1;
  String? _legacyScheduleNote;
  Offset? _lastInteractionPosition;
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
  static const int _scheduleStartHour = 8;
  static const int _scheduleEndHour = 20;
  static const int _minutesPerSlot = 30;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 60;
  static const double _dayLabelWidth = 96;
  static const double _blockVerticalInset = 0;
  static const double _rangeSelectionActivationThreshold = 8;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  int get _slotsPerHour => math.max(1, 60 ~/ _minutesPerSlot);

  int get _totalSlots => (_scheduleEndHour - _scheduleStartHour) * _slotsPerHour;

  double get _slotWidth => _scheduleHourWidth / _slotsPerHour;

  Rect? _highlightRectForSelection(int dayIndex, int startSlot, int durationSlots) {
    final int safeDayIndex = _clampInt(dayIndex, 0, _dayLabels.length - 1);
    final GlobalKey stackKey = _dayStackKeys[safeDayIndex];
    final RenderBox? stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) {
      return null;
    }

    final double highlightLeft = startSlot * _slotWidth;
    final double highlightWidth = durationSlots * _slotWidth;
    final Offset topLeft = stackBox.localToGlobal(
      Offset(highlightLeft, _blockVerticalInset),
    );
    final Offset bottomRight = stackBox.localToGlobal(
      Offset(highlightLeft + highlightWidth, stackBox.size.height - _blockVerticalInset),
    );
    return Rect.fromPoints(topLeft, bottomRight);
  }

  Offset? _highlightCenterForSelection(int dayIndex, int startSlot, int durationSlots) {
    final Rect? rect = _highlightRectForSelection(dayIndex, startSlot, durationSlots);
    if (rect == null) {
      return null;
    }
    return Offset(
      (rect.left + rect.right) / 2,
      (rect.top + rect.bottom) / 2,
    );
  }

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
    _loadTutorProfile();
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

  Future<void> _loadTutorProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final AuthProvider authProvider = context.read<AuthProvider>();
      final Tutor? impersonatedTutor = authProvider.currentTutor;
      String? tutorId = impersonatedTutor?.id;
      Map<String, dynamic>? data;

      if (tutorId != null && tutorId.isNotEmpty) {
        data = await _tutorService.fetchTutorDocument(tutorId);
      } else {
        final User? user = FirebaseAuth.instance.currentUser;
        tutorId = user?.uid;
        if (tutorId != null && tutorId.isNotEmpty) {
          data = await _tutorService.fetchTutorDocument(tutorId);
        }
      }

      if (!mounted) {
        return;
      }

      if (tutorId == null || tutorId.isEmpty) {
        setState(() {
          _tutorId = null;
          _tutorDocumentData = null;
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลผู้สอน กรุณาเข้าสู่ระบบใหม่')),
        );
        return;
      }

      if (data == null) {
        setState(() {
          _tutorId = tutorId;
          _tutorDocumentData = null;
          _isLoadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลผู้สอนในระบบ')),
        );
        return;
      }

      final List<String> subjects = (data['subjects'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value?.toString())
          .whereType<String>()
          .toList();

      setState(() {
        _tutorId = tutorId;
        _email = data['email'] as String? ?? '';
        _password = data['password'] as String? ?? '';
        _photoUrl = data['photoUrl'] as String?;
        _profileImageBase64 = null;
        _newProfileImageBytes = null;
        _removeExistingPhoto = false;
        _selectedSubjects = subjects;
        _scheduleBlocks = <ScheduleBlock>[];
        _legacyScheduleNote = null;
        _nextBlockId = 1;
        final String? scheduleSerialized = data['scheduleSerialized'] as String?;
        final dynamic scheduleRaw = data['schedule'];
        if (scheduleSerialized != null && scheduleSerialized.isNotEmpty) {
          _loadScheduleFromString(scheduleSerialized);
        } else if (scheduleRaw is String) {
          _loadScheduleFromString(scheduleRaw);
        } else if (scheduleRaw is List) {
          _loadScheduleFromFirestore(scheduleRaw);
        }
        _tutorDocumentData = data;
        _isLoadingProfile = false;
      });

      _fullNameController.text = data['fullName'] as String? ?? '';
      _nicknameController.text = data['nickname'] as String? ?? '';
      _lineIdController.text = data['lineId'] as String? ?? '';
      _phoneController.text = data['phone'] as String? ?? '';
      _currentActivityController.text = data['currentStatus'] as String? ?? '';
      _travelDurationController.text = data['travelTime'] as String? ?? '';
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingProfile = false;
        _tutorDocumentData = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโหลดข้อมูลผู้สอนได้: $error')),
      );
    }
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

  void _loadScheduleFromFirestore(List<dynamic> rawList) {
    final List<ScheduleBlock> parsedBlocks = <ScheduleBlock>[];
    final Set<int> usedIds = <int>{};
    int provisionalId = 0;

    for (final dynamic entry in rawList) {
      Map<String, dynamic>? mapEntry;
      if (entry is Map<String, dynamic>) {
        mapEntry = Map<String, dynamic>.from(entry);
      } else if (entry is Map) {
        mapEntry = Map<String, dynamic>.from(entry.cast<dynamic, dynamic>());
      }
      if (mapEntry == null) {
        continue;
      }

      final int? dayValue = mapEntry['day'] is int
          ? mapEntry['day'] as int
          : mapEntry['dayIndex'] is int
              ? mapEntry['dayIndex'] as int
              : null;
      int? startSlot = mapEntry['startSlot'] is int ? mapEntry['startSlot'] as int : null;
      int? durationSlots = mapEntry['durationSlots'] is int
          ? mapEntry['durationSlots'] as int
          : mapEntry['duration'] is int
              ? mapEntry['duration'] as int
              : null;

      final String? startTime = mapEntry['start'] as String? ?? mapEntry['startTime'] as String?;
      final String? endTime = mapEntry['end'] as String? ?? mapEntry['endTime'] as String?;

      startSlot ??= _slotFromTimeString(startTime);
      durationSlots ??= _durationFromTimes(startTime, endTime);

      if (dayValue == null || startSlot == null || durationSlots == null) {
        continue;
      }

      final int resolvedDayIndex = _resolveDayIndexFromStored(dayValue);
      final int safeStart = _clampInt(startSlot, 0, _totalSlots - 1);
      final int maxDuration = _totalSlots - safeStart;
      if (maxDuration <= 0) {
        continue;
      }
      final int safeDuration = _clampInt(durationSlots, 1, maxDuration);

      DateTime? blockDate;
      final dynamic rawDate = mapEntry['date'];
      if (rawDate is String && rawDate.isNotEmpty) {
        try {
          blockDate = DateTime.parse(rawDate);
        } catch (_) {
          blockDate = null;
        }
      }

      final bool isRecurring = mapEntry['isRecurring'] is bool
          ? mapEntry['isRecurring'] as bool
          : blockDate == null;

      final String? studentNameRaw = mapEntry['studentName'] as String?;
      final String? noteRaw = mapEntry['note'] as String?;
      final String? resolvedNote = () {
        if (studentNameRaw != null && studentNameRaw.trim().isNotEmpty) {
          return studentNameRaw.trim();
        }
        if (noteRaw != null && noteRaw.trim().isNotEmpty) {
          return noteRaw.trim();
        }
        return null;
      }();

      int resolvedId = mapEntry['id'] is int ? mapEntry['id'] as int : -1;
      if (resolvedId <= 0 || usedIds.contains(resolvedId)) {
        do {
          provisionalId++;
        } while (usedIds.contains(provisionalId));
        resolvedId = provisionalId;
      }

      final ScheduleBlock block = ScheduleBlock(
        id: resolvedId,
        dayIndex: resolvedDayIndex,
        startSlot: safeStart,
        durationSlots: safeDuration,
        type: ScheduleBlockType.teaching,
        note: resolvedNote,
        date: blockDate != null ? _normalizeDate(blockDate) : null,
        isRecurring: isRecurring,
      );

      final DateTime placementDay = block.date != null
          ? _normalizeDate(block.date!)
          : _pseudoDateForDayIndex(block.dayIndex);
      if (_canPlaceBlock(placementDay, block.startSlot, block.durationSlots, existing: parsedBlocks)) {
        parsedBlocks.add(block);
        usedIds.add(resolvedId);
      }
    }

    parsedBlocks.sort((ScheduleBlock a, ScheduleBlock b) {
      final DateTime anchorA = _sortAnchorForBlock(a);
      final DateTime anchorB = _sortAnchorForBlock(b);
      final int compare = anchorA.compareTo(anchorB);
      if (compare != 0) {
        return compare;
      }
      return a.id.compareTo(b.id);
    });

    _scheduleBlocks = parsedBlocks;
    if (_scheduleBlocks.isNotEmpty) {
      _nextBlockId = _scheduleBlocks.map((ScheduleBlock block) => block.id).reduce(math.max) + 1;
    } else {
      _nextBlockId = 1;
    }
  }

  int _resolveDayIndexFromStored(int rawValue) {
    if (rawValue >= 1 && rawValue <= 7) {
      final int weekday = rawValue == 7 ? DateTime.sunday : rawValue;
      return _dayIndexForWeekday(weekday);
    }
    return _clampInt(rawValue, 0, _dayLabels.length - 1);
  }

  int _weekdayFromDayIndex(int dayIndex) {
    const List<int> mapping = <int>[
      DateTime.saturday,
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    ];
    final int safeIndex = _clampInt(dayIndex, 0, mapping.length - 1);
    return mapping[safeIndex];
  }

  int? _minutesSinceScheduleStart(String? timeValue) {
    if (timeValue == null) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeValue.trim());
    if (match == null) {
      return null;
    }
    final int? hour = int.tryParse(match.group(1)!);
    final int? minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute - _scheduleStartHour * 60;
  }

  int? _slotFromTimeString(String? value) {
    final int? minutes = _minutesSinceScheduleStart(value);
    if (minutes == null) {
      return null;
    }
    final double slot = minutes / _minutesPerSlot;
    if (slot.isNaN) {
      return null;
    }
    if (slot < 0) {
      return 0;
    }
    return slot.floor();
  }

  int? _durationFromTimes(String? start, String? end) {
    final int? startMinutes = _minutesSinceScheduleStart(start);
    final int? endMinutes = _minutesSinceScheduleStart(end);
    if (startMinutes == null || endMinutes == null) {
      return null;
    }
    final int difference = endMinutes - startMinutes;
    if (difference <= 0) {
      return null;
    }
    final int durationSlots = (difference / _minutesPerSlot).ceil();
    return durationSlots > 0 ? durationSlots : null;
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

  List<Map<String, dynamic>> _serializeScheduleForFirestore() {
    if (_scheduleBlocks.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    _sortBlocks();
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final ScheduleBlock block in _scheduleBlocks) {
      final DateTime baseDay = block.date != null
          ? _normalizeDate(block.date!)
          : _pseudoDateForDayIndex(block.dayIndex);
      final DateTime start = _blockStartDateTime(baseDay, block.startSlot);
      final DateTime end = _blockEndDateTime(baseDay, block.startSlot, block.durationSlots);
      result.add(<String, dynamic>{
        'day': block.date != null ? block.date!.weekday : _weekdayFromDayIndex(block.dayIndex),
        'start': _formatTime(start),
        'end': _formatTime(end),
        if (block.note != null && block.note!.trim().isNotEmpty) 'studentName': block.note,
        'isRecurring': block.isRecurring,
        if (block.date != null) 'date': block.date!.toIso8601String(),
      });
    }
    return result;
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
    _lastInteractionPosition = details.globalPosition;
    _rangeSelectionPrimed = true;
  }

  void _handleRangePanStart(int dayIndex, DragStartDetails details) {
    _acquireScheduleHold();
    _pendingRangeDayIndex ??= dayIndex;
    _pendingRangeLocalOffset ??= details.localPosition;
    _pendingRangeGlobalOffset ??= details.globalPosition;
    _lastInteractionPosition = details.globalPosition;
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
  _lastInteractionPosition = globalPosition;
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
    _lastInteractionPosition = details.globalPosition;
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

final Rect? highlightRect =
    _highlightRectForSelection(dayIndex, startSlot, durationSlots);

// ✅ ให้ dropdown อยู่ตรง "กลางบล็อกที่เลือก" พอดี
final Offset popupCenter = highlightRect != null
    ? Offset(
        highlightRect.center.dx,
        highlightRect.top + (highlightRect.height / 2), // กึ่งกลางแนวตั้งของ highlight
      )
    : (_lastInteractionPosition ?? Offset.zero);


// ✅ dropdown อยู่ตรงกลางบล็อกจริง
final ScheduleBlockType? type = await _showBlockTypeChooser(
  position: popupCenter,
);

if (!mounted || type == null) {
  debugPrint('🚫 ยกเลิกเลือกประเภท block');
  return;
}

await Future.delayed(const Duration(milliseconds: 250));

// ✅ ถ้าเลือก "ไม่ว่าง" → สร้างบล็อกทันที ไม่ต้องกรอกอะไร
if (type == ScheduleBlockType.unavailable) {
  final ScheduleBlock newBlock = ScheduleBlock(
    id: _nextBlockId++,
    dayIndex: dayIndex,
    startSlot: startSlot,
    durationSlots: durationSlots,
    type: type,
    date: _normalizeDate(_currentWeekDates[dayIndex]),
    isRecurring: false,
  );

  setState(() {
    _scheduleBlocks = [..._scheduleBlocks, newBlock];
    _sortBlocks();
  });

  debugPrint('🚫 เพิ่ม block ไม่ว่าง slot=$startSlot dur=$durationSlots');
  return; // ✅ ออกจากฟังก์ชันทันที
}

// 🧩 ถ้าไม่ใช่ "ไม่ว่าง" → เปิด modal กรอกข้อมูลปกติ
final _BlockDetails? detailsResult = await _collectBlockDetails(
  type: type,
  dayIndex: dayIndex,
  dayDate: _currentWeekDates[dayIndex],
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


  // ✅ สร้างบล็อกใหม่final ScheduleBlockType? type = await _showBlockTypeChooser(

  final ScheduleBlock newBlock = ScheduleBlock(
    id: _nextBlockId++,
    dayIndex: detailsResult.dayIndex,
    startSlot: startSlot,
    durationSlots: detailsResult.durationSlots,
    type: type,
    note: detailsResult.note,
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

  Future<void> _handleGridTap(int dayIndex, Offset localPosition, Offset globalPosition) async {
    await _handleEmptySpaceTap(
      dayIndex: dayIndex,
      localPosition: localPosition,
      globalPosition: globalPosition,
    );
  }

  Future<void> _handleEmptySpaceTap({
    required int dayIndex,
    required Offset localPosition,
    required Offset globalPosition,
  }) async {
    final int slot = _slotFromDx(localPosition.dx);
    final DateTime dayDate = _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];
    final DateTime normalizedDate = _normalizeDate(dayDate);
    final bool hasExistingBlock = _scheduleBlocks.any((ScheduleBlock block) {
      if (!_blockOccursOnDate(block, normalizedDate, dayIndex)) {
        return false;
      }
      final int start = block.startSlot;
      final int end = block.startSlot + block.durationSlots;
      return slot >= start && slot < end;
    });
    if (hasExistingBlock) {
      return;
    }
    if (!_canPlaceBlock(dayDate, slot, 1)) {
      return;
    }
    final int maxDuration = _calculateMaxDuration(dayDate, slot, null);
    if (maxDuration <= 0) {
      return;
    }

    _lastInteractionPosition = globalPosition;
    final ScheduleBlockType? type = await _showBlockTypeChooser(position: globalPosition);
    if (!mounted || type == null) {
      return;
    }

    final _BlockDetails? detailsResult = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      dayDate: dayDate,
      initialDuration: 1,
    );

    if (!mounted || detailsResult == null) {
      return;
    }

    if (!_canPlaceBlock(detailsResult.dayDate, slot, detailsResult.durationSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
      );
      return;
    }

    final ScheduleBlock newBlock = ScheduleBlock(
      id: _nextBlockId++,
      dayIndex: _dayIndexForDate(detailsResult.dayDate),
      startSlot: slot,
      durationSlots: detailsResult.durationSlots,
      type: type,
      note: detailsResult.note,
      date: _normalizeDate(detailsResult.dayDate),
      isRecurring: detailsResult.isRecurring,
    );

    setState(() {
      _scheduleBlocks = <ScheduleBlock>[..._scheduleBlocks, newBlock];
      _legacyScheduleNote = null;
      _sortBlocks();
    });
  }

  Future<ScheduleBlockType?> _showBlockTypeChooser({Offset? position, Rect? anchorRect}) async {
    final OverlayState? overlay = Overlay.of(context);
    if (overlay != null) {
      final RenderObject? overlayRenderObject = overlay.context.findRenderObject();
      if (overlayRenderObject is RenderBox) {
        final RenderBox overlayBox = overlayRenderObject;
        RelativeRect menuPosition;
        if (anchorRect != null) {
          final Offset topLeft = overlayBox.globalToLocal(anchorRect.topLeft);
          final Offset bottomRight = overlayBox.globalToLocal(anchorRect.bottomRight);
          final Rect localRect = Rect.fromPoints(topLeft, bottomRight);
          menuPosition = RelativeRect.fromRect(localRect, Offset.zero & overlayBox.size);
        } else {
        final double menuWidth = 160;  // ✅ กว้างประมาณของ popup จริง
final double menuHeight = 90;  // ✅ สูงประมาณเมนู 2 ปุ่ม

final Offset resolvedPosition = position ?? overlayBox.size.center(Offset.zero);

// ✅ ให้ “กึ่งกลางของ dropdown” อยู่ตรง “กึ่งกลาง highlight”
menuPosition = RelativeRect.fromLTRB(
  resolvedPosition.dx - (menuWidth / 2),
  resolvedPosition.dy - (menuHeight / 2),
  overlayBox.size.width - (resolvedPosition.dx + menuWidth / 2),
  overlayBox.size.height - (resolvedPosition.dy + menuHeight / 2),
);

        }

        final ScheduleBlockType? selection = await showMenu<ScheduleBlockType>(
          context: context,
          position: menuPosition,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          items: <PopupMenuEntry<ScheduleBlockType>>[
            PopupMenuItem<ScheduleBlockType>(
              value: ScheduleBlockType.teaching,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  'สอน',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            PopupMenuItem<ScheduleBlockType>(
              value: ScheduleBlockType.unavailable,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  'ไม่ว่าง',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
        if (selection != null) {
          return selection;
        }
      }
    }

    return null;
  }

  Future<_BlockDetails?> _collectBlockDetails({
    required ScheduleBlockType type,
    required int dayIndex,
    required DateTime dayDate,
    int? initialDuration,
    String? initialNote,
    bool initialRecurring = false,
    bool allowDelete = false,
  }) async {
    final int durationSlots = initialDuration ?? 1;
    final TextEditingController noteController = TextEditingController(text: initialNote ?? '');

    final _BlockDetails? result = await showDialog<_BlockDetails>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog( 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: noteController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'รายละเอียด',
                        hintText: 'เช่น น้องตรัง คณิต ม.2',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        if (allowDelete)
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(
                                _BlockDetails(
                                  dayIndex: dayIndex,
                                  dayDate: _normalizeDate(dayDate),
                                  durationSlots: durationSlots,
                                  note: null,
                                  isRecurring: initialRecurring,
                                  shouldDelete: true,
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade400,
                            ),
                            child: const Text('ลบ'),
                          ),
                        if (allowDelete) const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('ยกเลิก'),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () {
                            final String trimmedNote = noteController.text.trim();
                            Navigator.of(dialogContext).pop(
                              _BlockDetails(
                                dayIndex: dayIndex,
                                dayDate: _normalizeDate(dayDate),
                                durationSlots: durationSlots,
                                note: trimmedNote.isEmpty ? null : trimmedNote,
                                isRecurring: initialRecurring,
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
          ),
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
    if (block.type == ScheduleBlockType.unavailable) {
      final bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('ไม่ว่าง'),
            content: const Text('ต้องการลบบล็อกเวลานี้หรือไม่?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ลบบล็อก'),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldDelete != true) {
        return;
      }

      setState(() {
        _scheduleBlocks =
            _scheduleBlocks.where((ScheduleBlock current) => current.id != block.id).toList();
      });
      return;
    }

    final _BlockDetails? details = await _collectBlockDetails(
      type: block.type,
      dayIndex: _dayIndexForDate(blockDisplayDate),
      dayDate: blockDisplayDate,
      initialDuration: block.durationSlots,
      initialNote: block.note,
      initialRecurring: block.isRecurring,
      allowDelete: true,
    );

    if (!mounted || details == null) {
      return;
    }

    if (details.shouldDelete) {
      setState(() {
        _scheduleBlocks =
            _scheduleBlocks.where((ScheduleBlock current) => current.id != block.id).toList();
      });
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
                    note: details.note,
                    date: _normalizeDate(details.dayDate),
                    isRecurring: block.type == ScheduleBlockType.teaching
                        ? details.isRecurring
                        : block.isRecurring,
                  )
                : current,
          )
          .toList();
      _sortBlocks();
    });
  }


  ImageProvider<Object>? _buildProfileImage(String? base64Data, String? networkUrl) {
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(base64Data));
      } catch (_) {
        // Fallback to network image if decoding fails.
      }
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return NetworkImage(networkUrl);
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tutorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้สอนในระบบ')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, dynamic> updateData = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'lineId': _lineIdController.text.trim(),
        'phone': _phoneController.text.trim(),
        'currentStatus': _currentActivityController.text.trim(),
        'travelTime': _travelDurationController.text.trim(),
        'subjects': List<String>.from(_selectedSubjects),
        'schedule': _serializeScheduleForFirestore(),
        'scheduleSerialized': _serializeScheduleBlocks(),
      };

      if (_email != null && _email!.isNotEmpty) {
        updateData['email'] = _email;
      }
      if (_password != null && _password!.isNotEmpty) {
        updateData['password'] = _password;
      }

      final TutorUpdateResult result = await _tutorService.updateTutor(
        tutorId: _tutorId!,
        data: updateData,
        newProfileImageBytes: _newProfileImageBytes,
        removePhoto: _removeExistingPhoto,
        existingPhotoPath: _tutorDocumentData?['photoPath'] as String?,
      );
      final bool removedPhoto = _removeExistingPhoto;
      final String? nextPhotoUrl = result.photoUrl ?? (removedPhoto ? null : _photoUrl);
      final String? nextPhotoPath = result.photoPath ??
          (removedPhoto ? null : _tutorDocumentData?['photoPath'] as String?);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _removeExistingPhoto = false;
        _photoUrl = nextPhotoUrl;
        _profileImageBase64 = null;
        _newProfileImageBytes = null;
        _tutorDocumentData = <String, dynamic>{
          ...?_tutorDocumentData,
          ...updateData,
          'photoUrl': nextPhotoUrl,
          'photoPath': nextPhotoPath,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
      );
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'ไม่สามารถบันทึกข้อมูลได้')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $error')),
      );
    }
  }

  Future<void> _handleLogout() async {
    await context.read<AuthProvider>().logout();
    if (!mounted) {
      return;
    }
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
      final Uint8List bytes = await file.readAsBytes();
      final String encoded = base64Encode(bytes);
      if (!mounted) {
        return;
      }
      setState(() {
        _profileImageBase64 = encoded;
        _newProfileImageBytes = bytes;
        _photoUrl = null;
        _removeExistingPhoto = false;
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
      _photoUrl = null;
      _newProfileImageBytes = null;
      _removeExistingPhoto = true;
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
              if ((_profileImageBase64 != null && _profileImageBase64!.isNotEmpty) ||
                  (_photoUrl != null && _photoUrl!.isNotEmpty))
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

  Widget _buildHeaderSection() {
    final ImageProvider<Object>? imageProvider =
        _buildProfileImage(_profileImageBase64, _photoUrl);
    String nicknameDisplay = _nicknameController.text.trim();
    if (nicknameDisplay.isEmpty) {
      final String? storedNickname = _tutorDocumentData != null
          ? _tutorDocumentData!['nickname'] as String?
          : null;
      nicknameDisplay = storedNickname?.trim() ?? '';
    }
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
              validator: (String? value) => null,
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
            _buildScheduleGrid(),
            const SizedBox(height: 8),
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
// ✅ เพิ่มครึ่งช่อง เพื่อให้เส้น 20:00 และบล็อกขวาสุดไม่โดนตัด
// ✅ เพิ่มอีกครึ่งช่อง เพื่อให้ 20:00 อยู่ในตารางพอดี
final double gridWidth =
    (_scheduleEndHour - _scheduleStartHour + 0.5) * _scheduleHourWidth;


     final List<int> hourLabels = List<int>.generate(
    _scheduleEndHour - _scheduleStartHour,
    (int index) => _scheduleStartHour + index,
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const SizedBox(height: 8),
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
                // 🔧 ส่วนหัวตารางเวลาทั้งแถว
Row(
  children: <Widget>[
    SizedBox(width: _dayLabelWidth, child: const SizedBox.shrink()),
SizedBox(
  // ✅ เพิ่มความกว้างอีกนิด ป้องกันเวลาโดนตัดขอบ
  width: gridWidth + 8, 
  child: Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      // 🕓 วาดเวลาทุกชั่วโมง ยกเว้น 20:00
      Row(
        children: <Widget>[
          ...List<int>.generate(
            _scheduleEndHour - _scheduleStartHour,
            (int i) => _scheduleStartHour + i,
          ).map(
            (int hour) => SizedBox(
              width: _scheduleHourWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    _formatTimeLabel(hour),
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

// ✅ วางป้าย 20:00 ให้ตรงเส้นขวาสุดในกรอบ (ไม่ล้น ไม่หาย)
      // ✅ วาง "20:00" ให้ตัว ":" อยู่ตรงเส้นขวาสุดพอดี
// ✅ วาง "20:00" ให้ตัว ":" อยู่ตรงเส้นขวาสุดของกริดพอดี
// ✅ วาง "20:00" ให้ ":" ตรงเส้นขวาสุดพอดี (ไม่โดนตัด)
Positioned(
  left: gridWidth - (_scheduleHourWidth * 0.43), // 👈 ปรับจาก 0.38 → 0.43
  top: 0,
  bottom: 0,
  child: Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 0),
      child: Text(
        _formatTimeLabel(_scheduleEndHour),
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
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
        ),
      ),
    ],
  );
}



  Widget _buildDayRow(int dayIndex, double gridWidth) {
    final int safeDayIndex = _clampInt(dayIndex, 0, _dayLabels.length - 1);
    final DateTime dayDate = _currentWeekDates[safeDayIndex];
    final GlobalKey stackKey = _dayStackKeys[safeDayIndex];
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
         Padding(
  padding: const EdgeInsets.only(right: 18.0), // ✅ เว้นขอบขวา 12px
  child: SizedBox(
    width: _dayLabelWidth,
    child: Align(
      alignment: Alignment.centerRight,
      child: Text(
        _dayLabels[safeDayIndex],
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        textAlign: TextAlign.right,
      ),
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
                        final DateTime dayDate =
                            _currentWeekDates[_clampInt(dayIndex, 0, _dayLabels.length - 1)];

                        setState(() {
                          _rangeSelectionDayIndex = dayIndex;
                          _rangeSelectionAnchorSlot = slot;
                          _currentSelectionRange =
                              _SelectionRange(startSlot: slot, durationSlots: 1);
                          _rangeSelectionSelectedDate = dayDate;
                        });

                        HapticFeedback.mediumImpact();
                        _lastInteractionPosition = details.globalPosition;
                      }
                      ..onLongPressMoveUpdate = (details) {
                        if (!_isRangeSelecting || _rangeSelectionAnchorSlot == null) {
                          return;
                        }

                        final int targetSlot = _slotFromDx(details.localPosition.dx);
                        final int anchor = _rangeSelectionAnchorSlot!;
                        final int start = math.min(anchor, targetSlot);
                        final int duration = (anchor - targetSlot).abs() + 1;

                        setState(() {
                          _currentSelectionRange =
                              _SelectionRange(startSlot: start, durationSlots: duration);
                        });
                        _lastInteractionPosition = details.globalPosition;
                      }
                      ..onLongPressEnd = (details) async {
                        if (!_isRangeSelecting || _currentSelectionRange == null) {
                          return;
                        }

                        final int dayIndexFinal = _rangeSelectionDayIndex ?? dayIndex;
                        final _SelectionRange selection = _currentSelectionRange!;
                        final int startSlot = selection.startSlot;
                        final int durationSlots = selection.durationSlots;

                        _lastInteractionPosition = details.globalPosition;

                        final Offset? popupCenter = _highlightCenterForSelection(
                          dayIndexFinal,
                          startSlot,
                          durationSlots,
                        );

                        // ✅ เรียกเมนูที่ตำแหน่งตรงกลางบล็อก
                        final ScheduleBlockType? type = await _showBlockTypeChooser(
                          position: popupCenter ?? details.globalPosition,
                        );


if (!mounted) {
  return;
}

if (type == null) {
  setState(() {
    _isRangeSelecting = false;
    _currentSelectionRange = null;
    _rangeSelectionAnchorSlot = null;
    _rangeSelectionDayIndex = null;
    _rangeSelectionSelectedDate = null;
  });
  return;
}

// ✅ ถ้าเลือก "ไม่ว่าง" → สร้าง block ทันที ไม่ต้องเปิด dialog
if (type == ScheduleBlockType.unavailable) {
  final ScheduleBlock newBlock = ScheduleBlock(
    id: _nextBlockId++,
    dayIndex: dayIndexFinal,
    startSlot: startSlot,
    durationSlots: durationSlots,
    type: type,
    date: _normalizeDate(_currentWeekDates[dayIndexFinal]),
    isRecurring: false,
  );

  setState(() {
    _scheduleBlocks = [..._scheduleBlocks, newBlock];
    _sortBlocks();
    _isRangeSelecting = false;
    _currentSelectionRange = null;
    _rangeSelectionAnchorSlot = null;
    _rangeSelectionDayIndex = null;
    _rangeSelectionSelectedDate = null;
  });

  debugPrint('🚫 เพิ่ม block ไม่ว่าง slot=$startSlot dur=$durationSlots');
  return; // ✅ ออกจากฟังก์ชันทันที
}

// 🩷 ถ้าเป็น "สอน" → เปิดให้กรอก note ตามเดิม
final _BlockDetails? detailsResult = await _collectBlockDetails(
  type: type,
  dayIndex: dayIndexFinal,
  dayDate: _currentWeekDates[dayIndexFinal],
  initialDuration: durationSlots,
);

                        if (!mounted) {
                          return;
                        }

                        if (detailsResult == null) {
                          setState(() {
                            _isRangeSelecting = false;
                            _currentSelectionRange = null;
                            _rangeSelectionAnchorSlot = null;
                            _rangeSelectionDayIndex = null;
                            _rangeSelectionSelectedDate = null;
                          });
                          return;
                        }

                        final ScheduleBlock newBlock = ScheduleBlock(
                          id: _nextBlockId++,
                          dayIndex: dayIndexFinal,
                          startSlot: startSlot,
                          durationSlots: detailsResult.durationSlots,
                          type: type,
                          note: detailsResult.note,
                          date: _normalizeDate(detailsResult.dayDate),
                          isRecurring: detailsResult.isRecurring,
                        );

                        setState(() {
                          _scheduleBlocks = [..._scheduleBlocks, newBlock];
                          _sortBlocks();
                          _isRangeSelecting = false;
                          _currentSelectionRange = null;
                          _rangeSelectionAnchorSlot = null;
                          _rangeSelectionDayIndex = null;
                          _rangeSelectionSelectedDate = null;
                        });

                        debugPrint('✅ เพิ่ม block สำเร็จ slot=$startSlot dur=$durationSlots');
                      }
                      ..onLongPressCancel = () {
                        debugPrint('🚫 ยกเลิก long press');
                        setState(() {
                          _isRangeSelecting = false;
                          _currentSelectionRange = null;
                          _rangeSelectionAnchorSlot = null;
                          _rangeSelectionDayIndex = null;
                          _rangeSelectionSelectedDate = null;
                        });
                        _lastInteractionPosition = null;
                      };
                  },
                ),
                TapGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTapUp = (TapUpDetails details) {
                      _handleEmptySpaceTap(
                        dayIndex: dayIndex,
                        localPosition: details.localPosition,
                        globalPosition: details.globalPosition,
                      );
                    };
                  },
                ),
              },
              behavior: HitTestBehavior.opaque,
              child: Stack(
                key: stackKey,
                clipBehavior: Clip.none,
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
          top: _blockVerticalInset,
          bottom: _blockVerticalInset,
          width: _currentSelectionRange!.durationSlots * _slotWidth,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.grey.shade300.withOpacity(0.7),
                borderRadius: BorderRadius.zero,
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
    final String? effectiveNote =
        block.note != null && block.note!.trim().isNotEmpty ? block.note!.trim() : null;
final String label = effectiveNote?.isNotEmpty == true
    ? effectiveNote!.trim()
    : (isTeaching ? 'สอน' : '');
final String tooltipLabel = effectiveNote?.isNotEmpty == true
    ? effectiveNote!.trim()
    : (isTeaching ? 'สอน' : '');
final bool hasLabel = label.isNotEmpty;

    final bool isRecurring = block.isRecurring && isTeaching;
    final bool isActive = _draggingBlockId == block.id;
    final bool isLifted = isActive && _isDragPrimed;
    final double topInset = _blockVerticalInset;
    final double bottomInset = _blockVerticalInset;
    final double liftOffset = isLifted ? -4 : 0;
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
              '${_formatDayWithDateFromDate(dayDate)} ${_formatSlotRange(dayDate, block.startSlot, block.durationSlots)}\n$tooltipLabel',
          waitDuration: const Duration(milliseconds: 400),
          child: Transform.translate(
            offset: Offset(0, liftOffset),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.zero,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (hasLabel)
                   Align(
  alignment: Alignment.center, // 🔥 จัดให้อยู่กลางทั้งแนวตั้งและแนวนอน
  child: Text(
    label!,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.center, // 🔥 เผื่อข้อความหลายบรรทัดให้จัดกลางด้วย
    style: TextStyle(
      color: textColor,
      fontWeight: FontWeight.w600,
    ),
  ),
),

                  if (isRecurring)
                    Align(
                      alignment: Alignment.topRight,
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
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : (_tutorDocumentData == null
                ? _buildEmptyState(context)
                : Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildHeaderSection(),
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
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    await _handleLogout();
                                  },
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
                  )),
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
    this.shouldDelete = false,
  });

  final int dayIndex;
  final DateTime dayDate;
  final int durationSlots;
  final String? note;
  final bool isRecurring;
  final bool shouldDelete;
}

class _SelectionRange {
  const _SelectionRange({required this.startSlot, required this.durationSlots});

  final int startSlot;
  final int durationSlots;
}

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
