import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'login_success_screen.dart';

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

class LoginDashboardScreen extends StatefulWidget {
  const LoginDashboardScreen({super.key});

  @override
  State<LoginDashboardScreen> createState() => _LoginDashboardScreenState();
}

class _LoginDashboardScreenState extends State<LoginDashboardScreen> {
  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 8;
  static const int _scheduleEndHour = 20;
  static const int _minutesPerSlot = 30;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 60;
  static const double _dayLabelWidth = 96;
  static const double _blockVerticalInset = 6;
  static const String _scheduleSerializationPrefix = 'SCHEDULE_V1:';

  final ScrollController _scheduleScrollController = ScrollController();
  final Map<String, List<ScheduleBlock>> _scheduleCache = <String, List<ScheduleBlock>>{};
  final Map<String, String?> _scheduleSignatures = <String, String?>{};
  final Set<String> _selectedSubjects = <String>{};

  int? _rangeSelectionDayIndex;
  int? _rangeSelectionAnchorSlot;
  _SelectionRange? _activeDragRange;
  _SelectionRange? _finalSelectionRange;
  int? _selectedDayIndex;

  int get _slotsPerHour => math.max(1, 60 ~/ _minutesPerSlot);
  int get _totalSlots => (_scheduleEndHour - _scheduleStartHour) * _slotsPerHour;
  double get _slotWidth => _scheduleHourWidth / _slotsPerHour;

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE4E1),
      appBar: AppBar(
        title: const Text('แดชบอร์ดติวเตอร์'),
        backgroundColor: const Color(0xFFFFE4E1),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<AuthProvider>(
            builder: (BuildContext context, AuthProvider authProvider, _) {
              if (authProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<Tutor> tutors = authProvider.tutors;
              final List<String> subjectOptions = _collectSubjectOptions(tutors);
              final List<Tutor> filteredTutors = _applyFilters(tutors);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _buildSubjectFilterButton(subjectOptions),
                      const SizedBox(width: 12),
                      if (_selectedSubjects.isNotEmpty)
                        TextButton(
                          onPressed: _clearSubjects,
                          child: const Text('ล้างตัวกรองวิชา'),
                        ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('ออกจากระบบ'),
                      ),
                    ],
                  ),
                  if (_selectedSubjects.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSubjects
                            .map(
                              (String subject) => Chip(
                                label: Text(subject),
                                onDeleted: () => _toggleSubject(subject),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildScheduleCard(),
                  const SizedBox(height: 16),
                  _buildFilterSummary(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildTutorList(filteredTutors),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectFilterButton(List<String> subjectOptions) {
    final bool enabled = subjectOptions.isNotEmpty;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'เลือกวิชาที่ต้องการดูครู',
      onSelected: (String subject) => _toggleSubject(subject),
      itemBuilder: (BuildContext context) {
        return subjectOptions
            .map(
              (String subject) => CheckedPopupMenuItem<String>(
                value: subject,
                checked: _selectedSubjects.contains(subject),
                child: Text(subject),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF3F51B5).withOpacity(0.12) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: enabled ? const Color(0xFF3F51B5) : const Color(0xFFBDBDBD),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.menu_book,
              color: enabled ? const Color(0xFF1A237E) : const Color(0xFF757575),
            ),
            const SizedBox(width: 8),
            Text(
              _subjectButtonLabel(),
              style: TextStyle(
                color: enabled ? const Color(0xFF1A237E) : const Color(0xFF757575),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: enabled ? const Color(0xFF1A237E) : const Color(0xFF757575),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'ตารางสอน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_finalSelectionRange != null && _selectedDayIndex != null)
                  TextButton.icon(
                    onPressed: _clearTimeFilter,
                    icon: const Icon(Icons.clear),
                    label: const Text('ล้างเวลาที่เลือก'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('แตะค้างแล้วลากเพื่อเลือกช่วงเวลาที่ต้องการตรวจสอบครูว่าง'),
            const SizedBox(height: 12),
            _buildScheduleGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSummary() {
    final String subjectSummary = _selectedSubjects.isEmpty
        ? 'ทุกวิชา'
        : _selectedSubjects.join(', ');
    final String timeSummary = _selectedDayIndex != null && _finalSelectionRange != null
        ? '${_dayLabels[_selectedDayIndex!]} • ${_formatSlotRange(_finalSelectionRange!.startSlot, _finalSelectionRange!.durationSlots)}'
        : 'ทุกวันและทุกเวลา';

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('วิชาที่คัดกรอง: $subjectSummary'),
                const SizedBox(height: 4),
                Text('เวลาที่คัดกรอง: $timeSummary'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleGrid() {
    final double gridWidth = (_scheduleEndHour - _scheduleStartHour + 0.5) * _scheduleHourWidth;
    final List<int> hourLabels = List<int>.generate(
      _scheduleEndHour - _scheduleStartHour,
      (int index) => _scheduleStartHour + index,
    );

    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          if (!_scheduleScrollController.hasClients) {
            return;
          }
          final double delta = -details.delta.dx;
          final double newOffset = (_scheduleScrollController.offset + delta).clamp(
            _scheduleScrollController.position.minScrollExtent,
            _scheduleScrollController.position.maxScrollExtent,
          );
          _scheduleScrollController.jumpTo(newOffset);
        },
        child: SingleChildScrollView(
          controller: _scheduleScrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const SizedBox(width: _dayLabelWidth),
                  SizedBox(
                    width: gridWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        children: hourLabels
                            .map(
                              (int hour) => SizedBox(
                                width: _scheduleHourWidth,
                                child: Text(
                                  _formatHourLabel(hour),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              for (int dayIndex = 0; dayIndex < _dayLabels.length; dayIndex++)
                _buildDayRow(dayIndex, gridWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayRow(int dayIndex, double gridWidth) {
    final _SelectionRange? selection = _selectionForDay(dayIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: _dayLabelWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _dayLabels[dayIndex],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          RawGestureDetector(
            gestures: <Type, GestureRecognizerFactory>{
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: const Duration(milliseconds: 180)),
                (LongPressGestureRecognizer instance) {
                  instance
                    ..onLongPressStart = (LongPressStartDetails details) {
                      final int slot = _slotFromDx(details.localPosition.dx);
                      setState(() {
                        _rangeSelectionDayIndex = dayIndex;
                        _rangeSelectionAnchorSlot = slot;
                        _activeDragRange = _SelectionRange(startSlot: slot, durationSlots: 1);
                      });
                    }
                    ..onLongPressMoveUpdate = (LongPressMoveUpdateDetails details) {
                      if (_rangeSelectionDayIndex != dayIndex || _rangeSelectionAnchorSlot == null) {
                        return;
                      }
                      final int targetSlot = _slotFromDx(details.localPosition.dx);
                      final int anchor = _rangeSelectionAnchorSlot!;
                      final int start = math.min(anchor, targetSlot);
                      final int duration = (anchor - targetSlot).abs() + 1;
                      setState(() {
                        _activeDragRange = _SelectionRange(startSlot: start, durationSlots: duration);
                      });
                    }
                    ..onLongPressEnd = (LongPressEndDetails details) {
                      if (_rangeSelectionDayIndex == dayIndex && _activeDragRange != null) {
                        setState(() {
                          _selectedDayIndex = dayIndex;
                          _finalSelectionRange = _activeDragRange;
                          _activeDragRange = null;
                          _rangeSelectionAnchorSlot = null;
                          _rangeSelectionDayIndex = null;
                        });
                      } else {
                        _clearActiveSelection();
                      }
                    }
                    ..onLongPressCancel = () {
                      _clearActiveSelection();
                    };
                },
              ),
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                width: gridWidth,
                height: _scheduleRowHeight,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CustomPaint(
                          painter: _ScheduleGridPainter(
                            hourWidth: _scheduleHourWidth,
                            totalHours: _scheduleEndHour - _scheduleStartHour,
                            slotsPerHour: _slotsPerHour,
                          ),
                        ),
                      ),
                    ),
                    if (selection != null)
                      Positioned(
                        left: selection.startSlot * _slotWidth,
                        top: _blockVerticalInset,
                        width: selection.durationSlots * _slotWidth,
                        height: _scheduleRowHeight - _blockVerticalInset * 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF3F51B5).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF3F51B5).withOpacity(0.6),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorList(List<Tutor> tutors) {
    if (tutors.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text('ไม่พบครูที่ตรงกับตัวกรองที่เลือก'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: tutors.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (BuildContext context, int index) {
          final Tutor tutor = tutors[index];
          final ImageProvider<Object>? profileImage = _buildProfileImage(tutor.profileImageBase64);
          final String displayName = tutor.nickname.isNotEmpty
              ? tutor.nickname
              : (tutor.firstName.isNotEmpty ? tutor.firstName : tutor.email);

          final String initials = displayName.trim().isNotEmpty
              ? displayName.trim().substring(0, 1).toUpperCase()
              : '?';

          return ListTile(
            onTap: () => _openTutorEditor(context, tutor),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8EAF6),
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.chevron_right),
          );
        },
      ),
    );
  }

  void _toggleSubject(String subject) {
    setState(() {
      if (_selectedSubjects.contains(subject)) {
        _selectedSubjects.remove(subject);
      } else {
        _selectedSubjects.add(subject);
      }
    });
  }

  void _clearSubjects() {
    if (_selectedSubjects.isEmpty) {
      return;
    }
    setState(() {
      _selectedSubjects.clear();
    });
  }

  void _clearTimeFilter() {
    setState(() {
      _finalSelectionRange = null;
      _selectedDayIndex = null;
      _activeDragRange = null;
      _rangeSelectionAnchorSlot = null;
      _rangeSelectionDayIndex = null;
    });
  }

  void _clearActiveSelection() {
    setState(() {
      _activeDragRange = null;
      _rangeSelectionAnchorSlot = null;
      _rangeSelectionDayIndex = null;
    });
  }

  void _handleLogout(BuildContext context) {
    final AuthProvider authProvider = context.read<AuthProvider>();
    authProvider.logout();
    Navigator.of(context).pushNamedAndRemoveUntil('/tutor-login', (Route<dynamic> route) => false);
  }

  void _openTutorEditor(BuildContext context, Tutor tutor) {
    final AuthProvider authProvider = context.read<AuthProvider>();
    authProvider.selectTutorForEditing(tutor);
    Navigator.pushNamed(
      context,
      '/login-success',
      arguments: const LoginSuccessArgs(
        title: 'โปรไฟล์ติวเตอร์',
        message: 'แก้ไขข้อมูลและตารางสอนได้จากหน้านี้',
      ),
    );
  }

  List<String> _collectSubjectOptions(List<Tutor> tutors) {
    final SplayTreeSet<String> uniqueSubjects = SplayTreeSet<String>();
    for (final Tutor tutor in tutors) {
      for (final String subject in tutor.subjects) {
        if (subject.trim().isEmpty) continue;
        uniqueSubjects.add(subject.trim());
      }
    }
    return uniqueSubjects.toList();
  }

  List<Tutor> _applyFilters(List<Tutor> tutors) {
    return tutors.where((Tutor tutor) {
      if (_selectedSubjects.isNotEmpty) {
        final bool matchesSubject = tutor.subjects.any(_selectedSubjects.contains);
        if (!matchesSubject) {
          return false;
        }
      }
      if (_selectedDayIndex != null && _finalSelectionRange != null) {
        final _SelectionRange range = _finalSelectionRange!;
        if (!_isTutorAvailable(tutor, _selectedDayIndex!, range.startSlot, range.durationSlots)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  _SelectionRange? _selectionForDay(int dayIndex) {
    if (_rangeSelectionDayIndex == dayIndex && _activeDragRange != null) {
      return _activeDragRange;
    }
    if (_selectedDayIndex == dayIndex && _finalSelectionRange != null) {
      return _finalSelectionRange;
    }
    return null;
  }

  int _slotFromDx(double dx) {
    final double maxWidth = _totalSlots * _slotWidth;
    final double adjustedDx = dx.clamp(0, maxWidth - 0.001);
    return _clampInt((adjustedDx / _slotWidth).floor(), 0, _totalSlots - 1);
  }

  String _formatHourLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _formatSlotRange(int startSlot, int durationSlots) {
    final DateTime start = DateTime(2000, 1, 1, _scheduleStartHour)
        .add(Duration(minutes: startSlot * _minutesPerSlot));
    final DateTime end = DateTime(2000, 1, 1, _scheduleStartHour)
        .add(Duration(minutes: (startSlot + durationSlots) * _minutesPerSlot));
    return '${_formatTime(start)} - ${_formatTime(end)}';
  }

  String _formatTime(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

  List<ScheduleBlock> _getTutorBlocks(Tutor tutor) {
    final String key = tutor.email.toLowerCase();
    final String? signature = tutor.teachingSchedule;
    if (_scheduleCache.containsKey(key) && _scheduleSignatures[key] == signature) {
      return _scheduleCache[key]!;
    }
    final List<ScheduleBlock> blocks = _parseScheduleBlocks(signature);
    _scheduleCache[key] = blocks;
    _scheduleSignatures[key] = signature;
    return blocks;
  }

  List<ScheduleBlock> _parseScheduleBlocks(String? raw) {
    if (raw == null) {
      return <ScheduleBlock>[];
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty || !trimmed.startsWith(_scheduleSerializationPrefix)) {
      return <ScheduleBlock>[];
    }
    try {
      final String payload = trimmed.substring(_scheduleSerializationPrefix.length);
      final Map<String, dynamic> data = jsonDecode(payload) as Map<String, dynamic>;
      final List<dynamic> blockList = (data['blocks'] as List<dynamic>?) ?? <dynamic>[];
      final int sourceMinutesPerSlot =
          (data['minutesPerSlot'] is int && (data['minutesPerSlot'] as int) > 0)
              ? data['minutesPerSlot'] as int
              : _minutesPerSlot;
      final List<ScheduleBlock> parsedBlocks = <ScheduleBlock>[];
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
        parsedBlocks.add(
          parsed.copyWith(
            dayIndex: safeDay,
            startSlot: safeStart,
            durationSlots: safeDuration,
            date: parsed.date != null ? _normalizeDate(parsed.date!) : null,
          ),
        );
      }
      parsedBlocks.sort((ScheduleBlock a, ScheduleBlock b) {
        final int dayCompare = a.dayIndex.compareTo(b.dayIndex);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.startSlot.compareTo(b.startSlot);
      });
      return parsedBlocks;
    } catch (_) {
      return <ScheduleBlock>[];
    }
  }

  bool _isTutorAvailable(Tutor tutor, int dayIndex, int startSlot, int durationSlots) {
    final List<ScheduleBlock> blocks = _getTutorBlocks(tutor);
    if (blocks.isEmpty) {
      return true;
    }
    final int selectedEnd = startSlot + durationSlots;
    for (final ScheduleBlock block in blocks) {
      if (!_blockAppliesOnDay(block, dayIndex)) {
        continue;
      }
      if (block.type != ScheduleBlockType.teaching && block.type != ScheduleBlockType.unavailable) {
        continue;
      }
      final int blockEnd = block.startSlot + block.durationSlots;
      if (startSlot < blockEnd && selectedEnd > block.startSlot) {
        return false;
      }
    }
    return true;
  }

  bool _blockAppliesOnDay(ScheduleBlock block, int dayIndex) {
    if (block.isRecurring) {
      final int recurringDay = block.date != null ? _dayIndexForDate(block.date!) : block.dayIndex;
      return recurringDay == dayIndex;
    }
    if (block.date != null) {
      return _dayIndexForDate(block.date!) == dayIndex;
    }
    return block.dayIndex == dayIndex;
  }

  DateTime _normalizeDate(DateTime input) => DateTime(input.year, input.month, input.day);

  int _dayIndexForWeekday(int weekday) => (weekday - DateTime.saturday + 7) % 7;

  int _dayIndexForDate(DateTime date) => _dayIndexForWeekday(date.weekday);

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  String _subjectButtonLabel() {
    if (_selectedSubjects.isEmpty) {
      return 'เลือกวิชา';
    }
    if (_selectedSubjects.length <= 2) {
      return _selectedSubjects.join(', ');
    }
    return 'เลือกแล้ว ${_selectedSubjects.length} วิชา';
  }
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
