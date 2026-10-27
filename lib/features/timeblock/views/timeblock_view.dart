import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/tempo_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/tempo_toast.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';
import '../widgets/now_indicator.dart';
import '../widgets/time_block_card.dart';
import '../widgets/time_block_dialog.dart';
import '../widgets/unscheduled_drawer.dart';

class TimeBlockView extends ConsumerStatefulWidget {
  const TimeBlockView({super.key});

  @override
  ConsumerState<TimeBlockView> createState() => _TimeBlockViewState();
}

class _TimeBlockViewState extends ConsumerState<TimeBlockView> {
  final ScrollController _timelineScrollController = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final GlobalKey _timelineGridKey = GlobalKey();
  static const double _hourHeight = 64.0;
  bool _showUnscheduledDrawer = false;

  // Live dragging and resizing state for buttery smooth tracking
  String? _activeDragBlockId;
  TimeBlock? _selectedBlock;
  double? _liveDragTop;
  double? _liveDragHeight;
  DateTime? _liveDragStart;
  DateTime? _liveDragEnd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final initialHour = now.hour >= 7 ? now.hour - 1 : 6;
      final targetOffset = initialHour * _hourHeight;
      if (_timelineScrollController.hasClients) {
        _timelineScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timelineScrollController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final db = ref.read(databaseProvider);

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_selectedBlock != null) {
        ref.read(timeBlockClipboardProvider.notifier).copy(_selectedBlock!);
        if (mounted) {
          TempoToast.show(context, 'Copied "${_selectedBlock!.title}"');
        }
      }
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyV) {
      final clipboard = ref.read(timeBlockClipboardProvider);
      if (clipboard != null) {
        final now = DateTime.now();
        final selectedDay = ref.read(selectedDayProvider);
        final duration = clipboard.endTime.difference(clipboard.startTime);
        final start = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          now.hour,
          (now.minute ~/ 15) * 15,
        );
        final pasted = TimeBlock(
          id: const Uuid().v4(),
          taskId: clipboard.taskId,
          subtaskId: clipboard.subtaskId,
          title: clipboard.title,
          startTime: start,
          endTime: start.add(duration),
          colorHex: clipboard.colorHex,
          isCompleted: false,
        );
        db.insertTimeBlock(pasted);
      }
    } else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (_selectedBlock != null) {
        final duration = _selectedBlock!.endTime.difference(
          _selectedBlock!.startTime,
        );
        final duplicated = TimeBlock(
          id: const Uuid().v4(),
          taskId: _selectedBlock!.taskId,
          subtaskId: _selectedBlock!.subtaskId,
          title: '${_selectedBlock!.title} (Copy)',
          startTime: _selectedBlock!.endTime,
          endTime: _selectedBlock!.endTime.add(duration),
          colorHex: _selectedBlock!.colorHex,
          isCompleted: false,
        );
        db.insertTimeBlock(duplicated);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_selectedBlock != null) {
        db.deleteTimeBlockById(_selectedBlock!.id);
        setState(() => _selectedBlock = null);
      }
    }
  }

  Future<void> _showBlockContextMenu(
    BuildContext context,
    Offset position,
    TimeBlock block,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);

    setState(() => _selectedBlock = block);

    final val = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: isDark
          ? TempoTheme.surfaceElevated
          : TempoTheme.lightSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem<String>(
          value: 'duplicate',
          child: Row(
            children: [
              Icon(CupertinoIcons.plus_square_on_square, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text('Duplicate', style: TextStyle(fontSize: 12.5)),
              ),
              Text('⌘D', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Row(
            children: [
              Icon(CupertinoIcons.doc_on_doc, size: 14),
              SizedBox(width: 8),
              Expanded(child: Text('Copy', style: TextStyle(fontSize: 12.5))),
              Text('⌘C', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                CupertinoIcons.trash,
                size: 14,
                color: TempoTheme.pastelRose,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: TempoTheme.pastelRose,
                  ),
                ),
              ),
              Text('Del', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );

    if (val == null || !mounted) return;

    if (val == 'duplicate') {
      final duration = block.endTime.difference(block.startTime);
      final newStart = block.endTime;
      final newEnd = newStart.add(duration);
      final duplicated = TimeBlock(
        id: const Uuid().v4(),
        taskId: block.taskId,
        subtaskId: block.subtaskId,
        title: '${block.title} (Copy)',
        startTime: newStart,
        endTime: newEnd,
        colorHex: block.colorHex,
        isCompleted: false,
      );
      await db.insertTimeBlock(duplicated);
    } else if (val == 'copy') {
      ref.read(timeBlockClipboardProvider.notifier).copy(block);
      if (context.mounted) {
        TempoToast.show(context, 'Copied time block to clipboard');
      }
    } else if (val == 'delete') {
      await db.deleteTimeBlockById(block.id);
    }
  }

  void _showEmptySlotContextMenu(
    BuildContext context,
    Offset position,
    DateTime day,
    int hour,
    int minute,
  ) {
    final clipboard = ref.read(timeBlockClipboardProvider);
    if (clipboard == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final db = ref.read(databaseProvider);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: isDark
          ? TempoTheme.surfaceElevated
          : TempoTheme.lightSurfaceElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'paste',
          child: Row(
            children: [
              const Icon(CupertinoIcons.doc_on_clipboard, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paste "${clipboard.title}"',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const Text(
                '⌘V',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    ).then((val) async {
      if (val == 'paste') {
        final duration = clipboard.endTime.difference(clipboard.startTime);
        final newStart = DateTime(day.year, day.month, day.day, hour, minute);
        final newEnd = newStart.add(duration);
        final pasted = TimeBlock(
          id: const Uuid().v4(),
          taskId: clipboard.taskId,
          subtaskId: clipboard.subtaskId,
          title: clipboard.title,
          startTime: newStart,
          endTime: newEnd,
          colorHex: clipboard.colorHex,
          isCompleted: false,
        );
        await db.insertTimeBlock(pasted);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final daysCount = ref.watch(timeBlockDaysCountProvider);
    final multiDayBlocksAsync = ref.watch(multiDayTimeBlocksStreamProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = ref.watch(customAccentColorProvider);

    final visibleDays = List.generate(
      daysCount,
      (i) => selectedDay.add(Duration(days: i)),
    );

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Row(
            children: [
              // Main Timeline Section
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // Refined Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          // Date Navigator (Previous Day / Week)
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(selectedDayProvider.notifier)
                                  .setDay(
                                    selectedDay.subtract(
                                      Duration(
                                        days: daysCount == 1 ? 1 : daysCount,
                                      ),
                                    ),
                                  );
                            },
                            icon: const Icon(
                              CupertinoIcons.chevron_left,
                              size: 14,
                            ),
                            color: isDark
                                ? TempoTheme.textSecondary
                                : TempoTheme.lightTextSecondary,
                          ),
                          Text(
                            daysCount == 1
                                ? (_isToday(selectedDay)
                                      ? 'Today • ${DateFormatter.formatMonthDay(selectedDay)}'
                                      : DateFormatter.formatFullDate(
                                          selectedDay,
                                        ))
                                : '${DateFormatter.formatMonthDay(selectedDay)} – ${DateFormatter.formatMonthDay(visibleDays.last)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? TempoTheme.textPrimary
                                  : TempoTheme.lightTextPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(selectedDayProvider.notifier)
                                  .setDay(
                                    selectedDay.add(
                                      Duration(
                                        days: daysCount == 1 ? 1 : daysCount,
                                      ),
                                    ),
                                  );
                            },
                            icon: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                            ),
                            color: isDark
                                ? TempoTheme.textSecondary
                                : TempoTheme.lightTextSecondary,
                          ),
                          if (!_isToday(selectedDay))
                            TextButton(
                              onPressed: () {
                                final now = DateTime.now();
                                ref
                                    .read(selectedDayProvider.notifier)
                                    .setDay(
                                      DateTime(now.year, now.month, now.day),
                                    );
                              },
                              child: Text(
                                'Today',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),

                          const SizedBox(width: 8),

                          // Multi-Day View Selector (1 Day, 3 Days, 5 Days, 7 Days)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDaysCountPill(
                                  '1D',
                                  1,
                                  daysCount,
                                  isDark,
                                  accentColor,
                                ),
                                _buildDaysCountPill(
                                  '3D',
                                  3,
                                  daysCount,
                                  isDark,
                                  accentColor,
                                ),
                                _buildDaysCountPill(
                                  '5D',
                                  5,
                                  daysCount,
                                  isDark,
                                  accentColor,
                                ),
                                _buildDaysCountPill(
                                  '7D',
                                  7,
                                  daysCount,
                                  isDark,
                                  accentColor,
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Toggle Unscheduled Drawer
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(
                                () => _showUnscheduledDrawer =
                                    !_showUnscheduledDrawer,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _showUnscheduledDrawer
                                    ? (isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : Colors.black.withValues(
                                              alpha: 0.08,
                                            ))
                                    : (isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            )),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.tray,
                                    size: 13,
                                    color: isDark
                                        ? TempoTheme.textSecondary
                                        : TempoTheme.lightTextSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Unscheduled Tasks',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: _showUnscheduledDrawer
                                          ? (isDark
                                                ? TempoTheme.textPrimary
                                                : TempoTheme.lightTextPrimary)
                                          : (isDark
                                                ? TempoTheme.textSecondary
                                                : TempoTheme
                                                      .lightTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // "+ Add Block" button
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              TimeBlockDialog.show(
                                context,
                                defaultDay: selectedDay,
                              );
                            },
                            icon: const Icon(CupertinoIcons.plus, size: 13),
                            label: const Text(
                              'Add Block',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Multi-Day High Contrast Frosted Headers (if daysCount > 1)
                    if (daysCount > 1)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(54, 4, 14, 6),
                        child: GlassContainer(
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 5,
                          ),
                          backgroundColor: isDark
                              ? TempoTheme.surfaceDark.withValues(alpha: 0.78)
                              : Colors.white.withValues(alpha: 0.85),
                          borderColor: Colors.transparent,
                          child: Row(
                            children: visibleDays.map((day) {
                              final isToday = _isToday(day);
                              return Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? accentColor.withValues(alpha: 0.16)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        DateFormatter.formatWeekday(day)
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isToday
                                              ? accentColor
                                              : (isDark
                                                    ? const Color(0xFFC7C7CC)
                                                    : const Color(0xFF3A3A3C)),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isToday
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isToday
                                              ? accentColor
                                              : (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1C1C1E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                    // 24-Hour Timeline Grid with Smooth Live Dragging & DragTarget support
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _timelineScrollController,
                        physics: const ClampingScrollPhysics(), // Clean, smooth, non-bouncy physics
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 80),
                        child: SizedBox(
                          key: _timelineGridKey,
                          height: 24 * _hourHeight,
                          child: multiDayBlocksAsync.when(
                            data: (allBlocks) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hourly Timeline Axis on the left (High Contrast)
                                  SizedBox(
                                    width: 44,
                                    height: 24 * _hourHeight,
                                    child: Stack(
                                      children: [
                                        for (var h = 0; h < 24; h++)
                                          Positioned(
                                            top: h * _hourHeight,
                                            left: 0,
                                            child: Text(
                                              '${h.toString().padLeft(2, '0')}:00',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? const Color(0xFFD1D1D6)
                                                    : const Color(0xFF3A3A3C),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Day Columns with DragTarget for Unscheduled Tasks AND Existing TimeBlocks across Dates
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: visibleDays.map((day) {
                                        final isToday = _isToday(day);
                                        final dayBlocks = allBlocks.where((b) {
                                          return b.startTime.year == day.year &&
                                              b.startTime.month == day.month &&
                                              b.startTime.day == day.day;
                                        }).toList();

                                        return Expanded(
                                          child: DragTarget<Object>(
                                            onWillAcceptWithDetails: (details) {
                                              if (details.data is TimeBlock &&
                                                  daysCount <= 1)
                                                return false;
                                              return details.data
                                                      is UnscheduledDragPayload ||
                                                  details.data is TimeBlock;
                                            },
                                            onAcceptWithDetails: (details) async {
                                              HapticFeedback.mediumImpact();
                                              final db = ref.read(
                                                databaseProvider,
                                              );
                                              final data = details.data;

                                              final gridBox =
                                                  _timelineGridKey
                                                          .currentContext
                                                          ?.findRenderObject()
                                                      as RenderBox?;
                                              final localOffset =
                                                  gridBox != null
                                                  ? gridBox.globalToLocal(
                                                      details.offset,
                                                    )
                                                  : Offset.zero;

                                              final timelineY = localOffset.dy
                                                  .clamp(
                                                    0.0,
                                                    24 * _hourHeight - 30,
                                                  );
                                              final rawMinutes =
                                                  (timelineY / _hourHeight * 60)
                                                      .round();
                                              final snappedMinutes =
                                                  ((rawMinutes / 15).round() *
                                                          15)
                                                      .clamp(0, 1425);

                                              if (data
                                                  is UnscheduledDragPayload) {
                                                final maxAllowedMinutes =
                                                    (1440 - data.durationMinutes)
                                                        .clamp(0, 1425);
                                                final safeMinutes =
                                                    snappedMinutes.clamp(
                                                      0,
                                                      maxAllowedMinutes,
                                                    );
                                                final startTime = DateTime(
                                                  day.year,
                                                  day.month,
                                                  day.day,
                                                  safeMinutes ~/ 60,
                                                  safeMinutes % 60,
                                                );
                                                final endTime = startTime.add(
                                                  Duration(
                                                    minutes:
                                                        data.durationMinutes,
                                                  ),
                                                );

                                                final newBlock = TimeBlock(
                                                  id: const Uuid().v4(),
                                                  taskId: data.taskId,
                                                  subtaskId: data.subtaskId,
                                                  title: data.title,
                                                  startTime: startTime,
                                                  endTime: endTime,
                                                  colorHex: data.colorHex,
                                                  isCompleted: false,
                                                );

                                                await db.insertTimeBlock(
                                                  newBlock,
                                                );
                                                if (context.mounted) {
                                                  TempoToast.show(
                                                    context,
                                                    'Scheduled "${data.title}" at ${DateFormatter.formatTime(startTime)}',
                                                  );
                                                }
                                              } else if (data is TimeBlock) {
                                                final duration = data.endTime
                                                    .difference(data.startTime);
                                                final originalStartMinutes =
                                                    data.startTime.hour * 60 +
                                                    data.startTime.minute;

                                                // If dropped within 30 minutes of original time-of-day, snap to exact original time-of-day
                                                // to prevent accidental vertical jumping when moving horizontally across days!
                                                final int targetMinutes;
                                                if ((snappedMinutes -
                                                            originalStartMinutes)
                                                        .abs() <=
                                                    30) {
                                                  targetMinutes =
                                                      originalStartMinutes;
                                                } else {
                                                  targetMinutes =
                                                      snappedMinutes;
                                                }

                                                // Clamp so duration never overflows midnight and compacts the block
                                                final maxAllowedMinutes =
                                                    (1440 - duration.inMinutes)
                                                        .clamp(0, 1425);
                                                final finalMinutes =
                                                    targetMinutes.clamp(
                                                      0,
                                                      maxAllowedMinutes,
                                                    );

                                                final startTime = DateTime(
                                                  day.year,
                                                  day.month,
                                                  day.day,
                                                  finalMinutes ~/ 60,
                                                  finalMinutes % 60,
                                                );
                                                final endTime = startTime.add(
                                                  duration,
                                                );
                                                await db.updateTimeBlockTime(
                                                  data.id,
                                                  startTime,
                                                  endTime,
                                                );
                                                if (context.mounted) {
                                                  TempoToast.show(
                                                    context,
                                                    'Moved "${data.title}" to ${DateFormatter.formatMonthDay(day)} at ${DateFormatter.formatTime(startTime)}',
                                                  );
                                                }
                                              }
                                            },
                                            builder: (context, candidateData, rejectedData) {
                                              final isCandidate =
                                                  candidateData.isNotEmpty;

                                              return GestureDetector(
                                                behavior:
                                                    HitTestBehavior.translucent,
                                                onSecondaryTapDown: (details) {
                                                  final gridBox =
                                                      _timelineGridKey
                                                              .currentContext
                                                              ?.findRenderObject()
                                                          as RenderBox?;
                                                  if (gridBox != null) {
                                                    final local = gridBox
                                                        .globalToLocal(
                                                          details
                                                              .globalPosition,
                                                        );
                                                    final timelineY = local.dy
                                                        .clamp(
                                                          0.0,
                                                          24 * _hourHeight - 30,
                                                        );
                                                    final rawMin =
                                                        (timelineY /
                                                                _hourHeight *
                                                                60)
                                                            .round();
                                                    final snapped =
                                                        ((rawMin / 15).round() *
                                                                15)
                                                            .clamp(0, 1425);
                                                    _showEmptySlotContextMenu(
                                                      context,
                                                      details.globalPosition,
                                                      day,
                                                      snapped ~/ 60,
                                                      snapped % 60,
                                                    );
                                                  }
                                                },
                                                child: Container(
                                                  margin:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isCandidate
                                                        ? accentColor
                                                              .withValues(
                                                                alpha: 0.10,
                                                              )
                                                        : Colors.transparent,
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: isDark
                                                            ? Colors.white
                                                                  .withValues(
                                                                    alpha: 0.08,
                                                                  )
                                                            : Colors.black
                                                                  .withValues(
                                                                    alpha: 0.06,
                                                                  ),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Stack(
                                                    children: [
                                                      // High-performance single-pass hourly & half-hourly gridlines
                                                      Positioned.fill(
                                                        child: RepaintBoundary(
                                                          child: CustomPaint(
                                                            painter: TimelineGridLinesPainter(
                                                              hourHeight: _hourHeight,
                                                              isDark: isDark,
                                                            ),
                                                          ),
                                                        ),
                                                      ),

                                                      // Now indicator (if viewing today)
                                                      if (isToday)
                                                        const NowIndicator(
                                                          hourHeight:
                                                              _hourHeight,
                                                        ),

                                                      // Draggable & Resizable Time Blocks across dates with High Contrast
                                                      ...dayBlocks.map((b) {
                                                        final isDraggingThis =
                                                            _activeDragBlockId ==
                                                            b.id;

                                                        final durationMinutes =
                                                            b.endTime
                                                                .difference(
                                                                  b.startTime,
                                                                )
                                                                .inMinutes
                                                                .clamp(
                                                                  15,
                                                                  1440,
                                                                );
                                                        final startMin =
                                                            b.startTime.hour *
                                                                60 +
                                                            b.startTime.minute;
                                                        final originalTop =
                                                            (startMin / 60.0) *
                                                            _hourHeight;
                                                        final originalHeight =
                                                            (durationMinutes /
                                                                60.0) *
                                                            _hourHeight;

                                                        final top =
                                                            (isDraggingThis &&
                                                                _liveDragTop !=
                                                                    null)
                                                            ? _liveDragTop!
                                                            : originalTop;
                                                        final height =
                                                            (isDraggingThis &&
                                                                _liveDragHeight !=
                                                                    null)
                                                            ? _liveDragHeight!
                                                            : originalHeight;

                                                        return Positioned(
                                                          top: top + 1,
                                                          left: 2,
                                                          right: 2,
                                                          height: (height - 2)
                                                              .clamp(
                                                                36.0,
                                                                24 *
                                                                    _hourHeight,
                                                              ),
                                                          child: Draggable<TimeBlock>(
                                                            data: b,
                                                            maxSimultaneousDrags:
                                                                daysCount > 1
                                                                ? 1
                                                                : 0,
                                                            dragAnchorStrategy:
                                                                (
                                                                  draggable,
                                                                  context,
                                                                  position,
                                                                ) {
                                                                  final h = (height - 2).clamp(36.0, 70.0);
                                                                  return Offset(80, h / 2);
                                                                },
                                                            feedback: Material(
                                                              color: Colors
                                                                  .transparent,
                                                              child: Transform.scale(
                                                                scale: 1.03,
                                                                child: Container(
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(10),
                                                                    boxShadow: [
                                                                      BoxShadow(
                                                                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
                                                                        blurRadius: 18,
                                                                        spreadRadius: 1,
                                                                        offset: const Offset(0, 8),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: SizedBox(
                                                                    width: 160,
                                                                    height:
                                                                        (height - 2)
                                                                            .clamp(
                                                                              36.0,
                                                                              24 *
                                                                                  _hourHeight,
                                                                            ),
                                                                    child:
                                                                        TimeBlockCard(
                                                                          block: b,
                                                                          onToggle:
                                                                              () {},
                                                                          onTap:
                                                                              () {},
                                                                          onDelete:
                                                                              () {},
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            childWhenDragging: Opacity(
                                                              opacity: 0.25,
                                                              child:
                                                                  TimeBlockCard(
                                                                    block: b,
                                                                    onToggle:
                                                                        () {},
                                                                    onTap:
                                                                        () {},
                                                                    onDelete:
                                                                        () {},
                                                                  ),
                                                            ),
                                                            child: TimeBlockCard(
                                                              block: b,
                                                              displayStartTime:
                                                                  isDraggingThis
                                                                  ? _liveDragStart
                                                                  : null,
                                                              displayEndTime:
                                                                  isDraggingThis
                                                                  ? _liveDragEnd
                                                                  : null,
                                                              onToggle: () async {
                                                                final db = ref.read(
                                                                  databaseProvider,
                                                                );
                                                                await db.toggleTimeBlock(
                                                                  b.id,
                                                                  !b.isCompleted,
                                                                );
                                                              },
                                                              onTap: () {
                                                                setState(
                                                                  () =>
                                                                      _selectedBlock =
                                                                          b,
                                                                );
                                                                TimeBlockDialog.show(
                                                                  context,
                                                                  initialBlock:
                                                                      b,
                                                                  defaultDay:
                                                                      day,
                                                                );
                                                              },
                                                              onDelete: () async {
                                                                final db = ref.read(
                                                                  databaseProvider,
                                                                );
                                                                await db
                                                                    .deleteTimeBlockById(
                                                                      b.id,
                                                                    );
                                                              },
                                                              onContextMenu:
                                                                  (pos) =>
                                                                      _showBlockContextMenu(
                                                                        context,
                                                                        pos,
                                                                        b,
                                                                      ),
                                                              // Vertical move callbacks (enabled only in 1-day view; multi-day uses Draggable)
                                                              onDragStart:
                                                                  daysCount == 1
                                                                  ? (_) {
                                                                      setState(() {
                                                                        _activeDragBlockId =
                                                                            b.id;
                                                                        _liveDragTop =
                                                                            originalTop;
                                                                        _liveDragHeight =
                                                                            originalHeight;
                                                                        _liveDragStart =
                                                                            b.startTime;
                                                                        _liveDragEnd =
                                                                            b.endTime;
                                                                      });
                                                                    }
                                                                  : null,
                                                              onDragUpdate:
                                                                  daysCount == 1
                                                                  ? (details) {
                                                                      if (_liveDragTop !=
                                                                          null) {
                                                                        // Preserve duration: do not let the bottom of the block exceed the timeline
                                                                        final maxTop = (24 * _hourHeight - originalHeight).clamp(
                                                                          0.0,
                                                                          24 * _hourHeight -
                                                                              32.0,
                                                                        );
                                                                        final newTop = (_liveDragTop! + details.delta.dy).clamp(
                                                                          0.0,
                                                                          maxTop,
                                                                        );
                                                                        final rawMinutes =
                                                                            (newTop / _hourHeight * 60).round();
                                                                        final maxAllowedMinutes =
                                                                            (1440 - durationMinutes).clamp(
                                                                              0,
                                                                              1425,
                                                                            );
                                                                        final snappedMinutes =
                                                                            ((rawMinutes / 15).round() * 15).clamp(
                                                                              0,
                                                                              maxAllowedMinutes,
                                                                            );

                                                                        final duration = b
                                                                            .endTime
                                                                            .difference(
                                                                              b.startTime,
                                                                            );
                                                                        final newStart = DateTime(
                                                                          day.year,
                                                                          day.month,
                                                                          day.day,
                                                                          snappedMinutes ~/
                                                                              60,
                                                                          snappedMinutes %
                                                                              60,
                                                                        );
                                                                        final newEnd =
                                                                            newStart.add(
                                                                              duration,
                                                                            );

                                                                        setState(() {
                                                                          _liveDragTop =
                                                                              newTop;
                                                                          _liveDragStart =
                                                                              newStart;
                                                                          _liveDragEnd =
                                                                              newEnd;
                                                                        });
                                                                      }
                                                                    }
                                                                  : null,
                                                              onDragEnd:
                                                                  daysCount == 1
                                                                  ? (_) async {
                                                                      if (_activeDragBlockId ==
                                                                              b.id &&
                                                                          _liveDragStart !=
                                                                              null &&
                                                                          _liveDragEnd !=
                                                                              null) {
                                                                        final db =
                                                                            ref.read(
                                                                              databaseProvider,
                                                                            );
                                                                        await db.updateTimeBlockTime(
                                                                          b.id,
                                                                          _liveDragStart!,
                                                                          _liveDragEnd!,
                                                                        );
                                                                      }
                                                                      setState(() {
                                                                        _activeDragBlockId =
                                                                            null;
                                                                        _liveDragTop =
                                                                            null;
                                                                        _liveDragHeight =
                                                                            null;
                                                                        _liveDragStart =
                                                                            null;
                                                                        _liveDragEnd =
                                                                            null;
                                                                      });
                                                                    }
                                                                  : null,
                                                              // Bottom resize callbacks
                                                              onResizeStart: (_) {
                                                                setState(() {
                                                                  _activeDragBlockId =
                                                                      b.id;
                                                                  _liveDragTop =
                                                                      originalTop;
                                                                  _liveDragHeight =
                                                                      originalHeight;
                                                                  _liveDragStart =
                                                                      b.startTime;
                                                                  _liveDragEnd =
                                                                      b.endTime;
                                                                });
                                                              },
                                                              onResizeUpdate: (details) {
                                                                if (_liveDragHeight !=
                                                                    null) {
                                                                  final startMinOfBlock =
                                                                      b.startTime.hour *
                                                                          60 +
                                                                      b
                                                                          .startTime
                                                                          .minute;
                                                                  final maxDurationMin =
                                                                      (1440 -
                                                                              startMinOfBlock)
                                                                          .clamp(
                                                                            15,
                                                                            1440,
                                                                          );
                                                                  final maxHeight =
                                                                      (maxDurationMin /
                                                                          60.0) *
                                                                      _hourHeight;
                                                                  final newHeight =
                                                                      (_liveDragHeight! +
                                                                              details.delta.dy)
                                                                          .clamp(
                                                                            32.0,
                                                                            maxHeight,
                                                                          );
                                                                  final rawMinutes =
                                                                      (newHeight /
                                                                              _hourHeight *
                                                                              60)
                                                                          .round();
                                                                  final snappedMinutes =
                                                                      ((rawMinutes / 15).round() * 15).clamp(
                                                                        15,
                                                                        maxDurationMin,
                                                                      );

                                                                  setState(() {
                                                                    _liveDragHeight =
                                                                        newHeight;
                                                                    _liveDragEnd = b
                                                                        .startTime
                                                                        .add(
                                                                          Duration(
                                                                            minutes:
                                                                                snappedMinutes,
                                                                          ),
                                                                        );
                                                                  });
                                                                }
                                                              },
                                                              onResizeEnd: (_) async {
                                                                if (_activeDragBlockId ==
                                                                        b.id &&
                                                                    _liveDragEnd !=
                                                                        null) {
                                                                  final db = ref
                                                                      .read(
                                                                        databaseProvider,
                                                                      );
                                                                  await db.updateTimeBlockTime(
                                                                    b.id,
                                                                    b.startTime,
                                                                    _liveDragEnd!,
                                                                  );
                                                                }
                                                                setState(() {
                                                                  _activeDragBlockId =
                                                                      null;
                                                                  _liveDragTop =
                                                                      null;
                                                                  _liveDragHeight =
                                                                      null;
                                                                  _liveDragStart =
                                                                      null;
                                                                  _liveDragEnd =
                                                                      null;
                                                                });
                                                              },
                                                            ),
                                                          ),
                                                        );
                                                      }),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (e, _) => Center(child: Text('Error: $e')),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Split View for Unscheduled Tasks Drawer
              if (_showUnscheduledDrawer)
                SizedBox(
                  width: isDesktop ? 320 : 260,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 14, 14),
                    child: UnscheduledDrawer(
                      selectedDay: selectedDay,
                      onClose: () =>
                          setState(() => _showUnscheduledDrawer = false),
                      onScheduleBlock: (block) async {
                        final db = ref.read(databaseProvider);
                        await db.insertTimeBlock(block);
                        if (context.mounted) {
                          TempoToast.show(
                            context,
                            'Scheduled "${block.title}"',
                          );
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaysCountPill(
    String label,
    int days,
    int currentDays,
    bool isDark,
    Color accentColor,
  ) {
    final isSelected = days == currentDays;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(timeBlockDaysCountProvider.notifier).setDays(days);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark
                      ? TempoTheme.textPrimary
                      : TempoTheme.lightTextPrimary)
                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }
}


/// High-performance painter for timeline gridlines
/// Draws all 48 lines in a single canvas draw pass with zero widget overhead
class TimelineGridLinesPainter extends CustomPainter {
  final double hourHeight;
  final bool isDark;

  const TimelineGridLinesPainter({required this.hourHeight, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final majorPaint = Paint()
      ..color = isDark ? const Color(0x14FFFFFF) : const Color(0x12000000)
      ..strokeWidth = 0.8;

    final minorPaint = Paint()
      ..color = isDark ? const Color(0x08FFFFFF) : const Color(0x08000000)
      ..strokeWidth = 0.5;

    for (var h = 0; h < 24; h++) {
      final yMajor = h * hourHeight;
      canvas.drawLine(Offset(0, yMajor), Offset(size.width, yMajor), majorPaint);

      final yMinor = (h + 0.5) * hourHeight;
      canvas.drawLine(Offset(0, yMinor), Offset(size.width, yMinor), minorPaint);
    }
  }

  @override
  bool shouldRepaint(TimelineGridLinesPainter oldDelegate) =>
      oldDelegate.hourHeight != hourHeight || oldDelegate.isDark != isDark;
}
