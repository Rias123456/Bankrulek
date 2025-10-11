import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

class StudyTable extends StatefulWidget {
  const StudyTable({
    super.key,
    required this.blocks,
    required this.onBlocksChanged,
    required this.generateBlockId,
    this.legacyNote,
    this.onLegacyNoteChanged,
    DateTime? initialDate,
    this.onDateChanged,
  }) : initialDate = initialDate ?? DateTime.now();

  final List<ScheduleBlock> blocks;
  final ValueChanged<List<ScheduleBlock>> onBlocksChanged;
  final int Function() generateBlockId;
  final String? legacyNote;
  final ValueChanged<String?>? onLegacyNoteChanged;
  final DateTime initialDate;
  final ValueChanged<DateTime>? onDateChanged;

  @override
  State<StudyTable> createState() => _StudyTableState();
}

class _StudyTableState extends State<StudyTable> {
  static const List<String> _dayLabels = <String>['เสาร์', 'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัส', 'ศุกร์'];
  static const int _scheduleStartHour = 7;
  static const int _scheduleEndHour = 21;
  static const double _scheduleHourWidth = 96;
  static const double _scheduleRowHeight = 72;
  static const double _dayLabelWidth = 80;
  static const double _rangeSelectionActivationThreshold = 8;

  late ScrollController _scheduleScrollController;
  ScrollHoldController? _scheduleHoldController;
  late DateTime _weekStart;

  List<ScheduleBlock> _blocks = <ScheduleBlock>[];
  String? _legacyNote;

  bool _canScrollBackward = false;
  bool _canScrollForward = false;

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
  int? _pendingRangeDayIndex;
  Offset? _pendingRangeLocalOffset;
  Offset? _pendingRangeGlobalOffset;

  int get _totalSlots => _scheduleEndHour - _scheduleStartHour;

  double get _slotWidth => _scheduleHourWidth;

  @override
  void initState() {
    super.initState();
    _blocks = List<ScheduleBlock>.from(widget.blocks);
    _legacyNote = widget.legacyNote;
    _weekStart = _alignToWeekStart(widget.initialDate);
    _scheduleScrollController = ScrollController();
    _scheduleScrollController.addListener(_handleScheduleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScheduleScrollChanged());
  }

  @override
  void dispose() {
    _scheduleScrollController.removeListener(_handleScheduleScrollChanged);
    _releaseScheduleHold();
    _scheduleScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudyTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.blocks, widget.blocks)) {
      _blocks = List<ScheduleBlock>.from(widget.blocks);
    }
    if (oldWidget.legacyNote != widget.legacyNote) {
      _legacyNote = widget.legacyNote;
    }
    if (oldWidget.initialDate != widget.initialDate) {
      _weekStart = _alignToWeekStart(widget.initialDate);
    }
  }

  DateTime _alignToWeekStart(DateTime date) {
    final DateTime normalized = DateTime(date.year, date.month, date.day);
    int diff = normalized.weekday - DateTime.saturday;
    if (diff < 0) {
      diff += 7;
    }
    return normalized.subtract(Duration(days: diff));
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

  void _releaseScheduleHold() {
    _scheduleHoldController?.cancel();
    _scheduleHoldController = null;
  }

  void _acquireScheduleHold() {
    if (_scheduleHoldController != null || !_scheduleScrollController.hasClients) {
      return;
    }
    _scheduleHoldController = _scheduleScrollController.position.hold(_handleScrollHoldCanceled);
  }

  void _handleScrollHoldCanceled() {
    _scheduleHoldController = null;
  }

  void _scrollScheduleBy(double delta) {
    if (!_scheduleScrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scheduleScrollController.position;
    final double target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 0.5) {
      return;
    }
    _scheduleScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _updateBlocks(List<ScheduleBlock> newBlocks) {
    final List<ScheduleBlock> sorted = List<ScheduleBlock>.from(newBlocks)
      ..sort((ScheduleBlock a, ScheduleBlock b) {
        final int dayCompare = a.dayIndex.compareTo(b.dayIndex);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return a.startSlot.compareTo(b.startSlot);
      });
    setState(() {
      _blocks = sorted;
    });
    widget.onBlocksChanged(List<ScheduleBlock>.from(sorted));
  }

  void _clearLegacyNote() {
    setState(() {
      _legacyNote = null;
    });
    widget.onLegacyNoteChanged?.call(null);
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
    final List<ScheduleBlock> source = existing ?? _blocks;
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
    final List<ScheduleBlock> dayBlocks = _blocks
        .where(
          (ScheduleBlock block) => block.dayIndex == dayIndex && (ignoreId == null || block.id != ignoreId),
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
    final int hours = slots;
    if (hours <= 0) {
      return '0 ชม.';
    }
    return '$hours ชม.';
  }

  String _formatTimeLabel(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _formatSlotRange(int startSlot, int durationSlots) {
    final DateTime start = DateTime(2020, 1, 1, _scheduleStartHour + startSlot);
    final DateTime end = start.add(Duration(hours: durationSlots));
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
      while (start < anchorSlot && !_canPlaceBlock(dayIndex, start, anchorSlot - start + 1)) {
        start += 1;
      }
      if (!_canPlaceBlock(dayIndex, start, anchorSlot - start + 1)) {
        start = anchorSlot;
        end = anchorSlot;
      }
    }
    return _SelectionRange(startSlot: start, durationSlots: end - start + 1);
  }

  void _startRangeSelection(int dayIndex, DragDownDetails details) {
    _acquireScheduleHold();
    _isRangeSelecting = true;
    _rangeSelectionDayIndex = dayIndex;
    _rangeSelectionAnchorSlot = _slotFromDx(details.localPosition.dx);
    _rangeSelectionStartDayIndex = dayIndex;
    _rangeSelectionStartGlobalDy = details.globalPosition.dy;
    _currentSelectionRange = _SelectionRange(startSlot: _rangeSelectionAnchorSlot!, durationSlots: 1);
    _rangeSelectionMoved = false;
    _rangeSelectionPrimed = false;
    _pendingRangeDayIndex = null;
    _pendingRangeLocalOffset = null;
    _pendingRangeGlobalOffset = null;
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
    final int targetDay = _clampInt(_rangeSelectionStartDayIndex! + dayOffset, 0, _dayLabels.length - 1);
    final _SelectionRange resolved = _resolveSelectionRange(targetDay, anchor, targetSlot);
    final bool moved = targetSlot != anchor || targetDay != _rangeSelectionDayIndex;
    if (_currentSelectionRange?.startSlot != resolved.startSlot ||
        _currentSelectionRange?.durationSlots != resolved.durationSlots) {
      setState(() {
        _currentSelectionRange = resolved;
        _rangeSelectionDayIndex = targetDay;
        _rangeSelectionMoved = _rangeSelectionMoved || moved;
      });
    } else if (moved && !_rangeSelectionMoved) {
      setState(() {
        _rangeSelectionDayIndex = targetDay;
        _rangeSelectionMoved = true;
      });
    } else if (_rangeSelectionDayIndex != targetDay) {
      setState(() {
        _rangeSelectionDayIndex = targetDay;
      });
    }
  }
  Future<void> _finishRangeSelection({DragEndDetails? details, bool cancelled = false}) async {
    if (!_isRangeSelecting) {
      _releaseScheduleHold();
      _clearPendingRangeSelection();
      _rangeSelectionMoved = false;
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
      _rangeSelectionStartDayIndex = null;
      _rangeSelectionStartGlobalDy = null;
      _currentSelectionRange = null;
      _rangeSelectionMoved = false;
    });
    _releaseScheduleHold();
    _clearPendingRangeSelection();

    if (!_canPlaceBlock(dayIndex, range.startSlot, range.durationSlots)) {
      return;
    }

    final ScheduleBlockType? type = await _showBlockTypeChooser();
    if (!mounted) {
      return;
    }
    if (type == null) {
      return;
    }

    final _BlockDetails? detailsResult = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      startSlot: range.startSlot,
      initialDuration: range.durationSlots,
    );
    if (!mounted) {
      return;
    }
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
      id: widget.generateBlockId(),
      dayIndex: detailsResult.dayIndex,
      startSlot: range.startSlot,
      durationSlots: detailsResult.durationSlots,
      type: type,
      note: type == ScheduleBlockType.teaching ? detailsResult.note : null,
    );

    _updateBlocks(<ScheduleBlock>[..._blocks, newBlock]);
    if (_legacyNote != null) {
      _clearLegacyNote();
    }
  }

  void _clearPendingRangeSelection() {
    _pendingRangeDayIndex = null;
    _pendingRangeLocalOffset = null;
    _pendingRangeGlobalOffset = null;
    _rangeSelectionPrimed = false;
  }

  void _cancelRangeSelection() {
    if (!_isRangeSelecting && _currentSelectionRange == null) {
      _releaseScheduleHold();
      _clearPendingRangeSelection();
      _rangeSelectionMoved = false;
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
    });
    _releaseScheduleHold();
    _clearPendingRangeSelection();
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
    if (!mounted) {
      return;
    }
    if (type == null) {
      return;
    }
    final _BlockDetails? details = await _collectBlockDetails(
      type: type,
      dayIndex: dayIndex,
      startSlot: slot,
    );
    if (!mounted) {
      return;
    }
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
      id: widget.generateBlockId(),
      dayIndex: details.dayIndex,
      startSlot: slot,
      durationSlots: details.durationSlots,
      type: type,
      note: type == ScheduleBlockType.teaching ? details.note : null,
    );
    _updateBlocks(<ScheduleBlock>[..._blocks, newBlock]);
    if (_legacyNote != null) {
      _clearLegacyNote();
    }
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
                  subtitle: 'บันทึกคาบสอนและรายละเอียด',
                  onTap: () => Navigator.pop(context, ScheduleBlockType.teaching),
                ),
                const SizedBox(height: 12),
                _buildBlockOption(
                  color: Colors.grey.shade300,
                  borderColor: Colors.grey.shade500,
                  textColor: Colors.grey.shade700,
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
      builder: (BuildContext _dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final bool isTeaching = type == ScheduleBlockType.teaching;
            final List<DateTime> weekDays =
                List<DateTime>.generate(_dayLabels.length, (int index) => _weekStart.add(Duration(days: index)));
            return AlertDialog(
              title: Text(isTeaching ? 'เพิ่มช่วงเวลาสอน' : 'ทำเครื่องหมายไม่ว่าง'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_buildDayLabel(selectedDay, weekDays[selectedDay])} ${_formatSlotRange(startSlot, duration)}',
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
                                Expanded(child: Text(_buildDayLabel(index, weekDays[index]))),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
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
                      ScaffoldMessenger.of(this.context).showSnackBar(
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
                            ? (noteController.text.trim().isEmpty ? null : noteController.text.trim())
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

    final List<ScheduleBlock> updated = _blocks
        .map(
          (ScheduleBlock current) => current.id == block.id
              ? current.copyWith(dayIndex: newDay, startSlot: newStart)
              : current,
        )
        .toList();
    _updateBlocks(updated);
    setState(() {
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
                Text(
                  '${_buildDayLabel(block.dayIndex, _weekStart.add(Duration(days: block.dayIndex)))}\n${_formatSlotRange(block.startSlot, block.durationSlots)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (block.type == ScheduleBlockType.teaching)
                  _buildActionOption(
                    icon: Icons.edit,
                    label: 'แก้ไขรายละเอียดคาบสอน',
                    onTap: () => Navigator.pop(context, _BlockAction.editTeaching),
                  )
                else
                  _buildActionOption(
                    icon: Icons.edit,
                    label: 'แปลงเป็นบล็อคสอน',
                    onTap: () => Navigator.pop(context, _BlockAction.convertToTeaching),
                  ),
                const SizedBox(height: 12),
                _buildActionOption(
                  icon: Icons.delete_outline,
                  label: 'ลบบล็อคนี้',
                  isDestructive: true,
                  onTap: () => Navigator.pop(context, _BlockAction.delete),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _BlockAction.editTeaching:
        if (block.type != ScheduleBlockType.teaching) {
          final _BlockDetails? details = await _collectBlockDetails(
            type: ScheduleBlockType.teaching,
            dayIndex: block.dayIndex,
            startSlot: block.startSlot,
            initialDuration: block.durationSlots,
            ignoreBlockId: block.id,
          );
          if (!mounted) {
            return;
          }
          if (details != null) {
            if (!_canPlaceBlock(details.dayIndex, block.startSlot, details.durationSlots, ignoreId: block.id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
              );
              return;
            }
            _updateBlocks(
              _blocks
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
                  .toList(),
            );
          }
        } else {
          final _BlockDetails? details = await _collectBlockDetails(
            type: ScheduleBlockType.teaching,
            dayIndex: block.dayIndex,
            startSlot: block.startSlot,
            initialDuration: block.durationSlots,
            initialNote: block.note,
            ignoreBlockId: block.id,
          );
          if (!mounted) {
            return;
          }
          if (details != null) {
            if (!_canPlaceBlock(details.dayIndex, block.startSlot, details.durationSlots, ignoreId: block.id)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
              );
              return;
            }
            _updateBlocks(
              _blocks
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
                  .toList(),
            );
          }
        }
        break;
      case _BlockAction.convertToTeaching:
        final _BlockDetails? details = await _collectBlockDetails(
          type: ScheduleBlockType.teaching,
          dayIndex: block.dayIndex,
          startSlot: block.startSlot,
          initialDuration: block.durationSlots,
          ignoreBlockId: block.id,
        );
        if (!mounted) {
          return;
        }
        if (details != null) {
          if (!_canPlaceBlock(details.dayIndex, block.startSlot, details.durationSlots, ignoreId: block.id)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ช่วงเวลานี้ถูกใช้ไปแล้ว')),
            );
            return;
          }
          _updateBlocks(
            _blocks
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
                .toList(),
          );
        }
        break;
      case _BlockAction.delete:
        _updateBlocks(_blocks.where((ScheduleBlock current) => current.id != block.id).toList());
        break;
    }
  }

  Widget _buildActionOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.grey.shade800),
      title: Text(
        label,
        style: TextStyle(color: isDestructive ? Colors.red : Colors.grey.shade800),
      ),
      onTap: onTap,
    );
  }

  void _primeRangeSelection(int dayIndex, Offset localPosition, Offset globalPosition) {
    _pendingRangeDayIndex = dayIndex;
    _pendingRangeLocalOffset = localPosition;
    _pendingRangeGlobalOffset = globalPosition;
    _rangeSelectionPrimed = true;
  }

  void _activatePrimedSelection() {
    if (!_rangeSelectionPrimed ||
        _pendingRangeDayIndex == null ||
        _pendingRangeLocalOffset == null ||
        _pendingRangeGlobalOffset == null) {
      return;
    }
    _startRangeSelection(
      _pendingRangeDayIndex!,
      DragDownDetails(
        globalPosition: _pendingRangeGlobalOffset!,
        localPosition: _pendingRangeLocalOffset!,
      ),
    );
    _rangeSelectionPrimed = false;
  }

  void _updatePendingSelection(Offset globalPosition) {
    if (!_rangeSelectionPrimed || _pendingRangeGlobalOffset == null) {
      return;
    }
    final double dy = (globalPosition.dy - _pendingRangeGlobalOffset!.dy).abs();
    if (dy >= _rangeSelectionActivationThreshold) {
      _activatePrimedSelection();
    }
  }

  String _buildDayLabel(int index, DateTime date) {
    return '${_dayLabels[index]} ${date.day}/${date.month}/${date.year + 543}';
  }

  void _handleChangeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
    widget.onDateChanged?.call(_weekStart);
  }

  Future<void> _handlePickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(now.year - 5, now.month, now.day),
      lastDate: DateTime(now.year + 5, now.month, now.day),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _weekStart = _alignToWeekStart(picked);
    });
    widget.onDateChanged?.call(_weekStart);
  }

  @override
  Widget build(BuildContext context) {
    final double gridWidth = (_scheduleEndHour - _scheduleStartHour) * _scheduleHourWidth;
    final List<int> hourLabels =
        List<int>.generate(_scheduleEndHour - _scheduleStartHour, (int index) => _scheduleStartHour + index);
    final double scrollStep = _scheduleHourWidth * 2;
    final List<DateTime> weekDays =
        List<DateTime>.generate(_dayLabels.length, (int index) => _weekStart.add(Duration(days: index)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'สัปดาห์ก่อนหน้า',
              onPressed: () => _handleChangeWeek(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: _handlePickDate,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
                child: Text(
                  'สัปดาห์ที่เริ่ม ${_weekStart.day}/${_weekStart.month}/${_weekStart.year + 543}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            IconButton(
              tooltip: 'สัปดาห์ถัดไป',
              onPressed: () => _handleChangeWeek(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        ClipRect(
          child: Listener(
            onPointerMove: (PointerMoveEvent event) {
              _updatePendingSelection(event.position);
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
                                for (final int hour in hourLabels)
                                  Container(
                                    width: _scheduleHourWidth,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ),
                                    child: Text(
                                      _formatTimeLabel(hour),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: 1,
                                  color: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Column(
                    children: <Widget>[
                      for (int dayIndex = 0; dayIndex < _dayLabels.length; dayIndex++)
                        _buildDayRow(dayIndex, weekDays[dayIndex], gridWidth),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'แตะหรือลากครอบช่วงเวลาเพื่อเพิ่มบล็อค และลากบล็อคเพื่อย้ายไปยังวันหรือเวลาอื่นได้',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        if (_legacyNote != null && _legacyNote!.isNotEmpty) ...<Widget>[
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
                onPressed: _clearLegacyNote,
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
              _legacyNote!,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayRow(int dayIndex, DateTime date, double gridWidth) {
    final List<ScheduleBlock> dayBlocks = _blocks.where((ScheduleBlock block) => block.dayIndex == dayIndex).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _dayLabelWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _dayLabels[dayIndex],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${date.day}/${date.month}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: _scheduleRowHeight,
              child: GestureDetector(
                onTapUp: (TapUpDetails details) => _handleGridTap(dayIndex, details.localPosition.dx),
                onTapDown: (TapDownDetails details) =>
                    _primeRangeSelection(dayIndex, details.localPosition, details.globalPosition),
                onTapCancel: _cancelRangeSelection,
                onHorizontalDragDown: (DragDownDetails details) => _startRangeSelection(dayIndex, details),
                onHorizontalDragUpdate: _updateRangeSelection,
                onHorizontalDragEnd: _finishRangeSelection,
                onHorizontalDragCancel: _cancelRangeSelection,
                onVerticalDragDown: (DragDownDetails details) => _startRangeSelection(dayIndex, details),
                onVerticalDragUpdate: _updateRangeSelection,
                onVerticalDragEnd: _finishRangeSelection,
                onVerticalDragCancel: _cancelRangeSelection,
                onPanDown: (DragDownDetails details) => _startRangeSelection(dayIndex, details),
                onPanUpdate: _updateRangeSelection,
                onPanEnd: _finishRangeSelection,
                onPanCancel: _cancelRangeSelection,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    if (_isRangeSelecting && _rangeSelectionDayIndex == dayIndex && _currentSelectionRange != null)
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
                              color: Colors.grey.shade300.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.shade500.withOpacity(0.7),
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
  const _SelectionRange({
    required this.startSlot,
    required this.durationSlots,
  });

  final int startSlot;
  final int durationSlots;
}

enum _BlockAction { editTeaching, convertToTeaching, delete }
