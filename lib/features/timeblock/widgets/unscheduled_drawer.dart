import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class UnscheduledDragPayload {
  final String title;
  final String? taskId;
  final String? subtaskId;
  final int colorHex;
  final int durationMinutes;

  const UnscheduledDragPayload({
    required this.title,
    this.taskId,
    this.subtaskId,
    required this.colorHex,
    required this.durationMinutes,
  });
}

class UnscheduledDrawer extends ConsumerWidget {
  final DateTime selectedDay;
  final VoidCallback onClose;
  final void Function(TimeBlock block) onScheduleBlock;

  const UnscheduledDrawer({
    super.key,
    required this.selectedDay,
    required this.onClose,
    required this.onScheduleBlock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allBlocksAsync = ref.watch(allTimeBlocksStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scheduledTaskIds = (allBlocksAsync.value ?? [])
        .map((b) => b.taskId)
        .whereType<String>()
        .toSet();
    final scheduledSubtaskIds = (allBlocksAsync.value ?? [])
        .map((b) => b.subtaskId)
        .whereType<String>()
        .toSet();

    final activeTasks = (tasksAsync.value ?? []).where((t) {
      if (t.isAllCompleted) return false;
      final isTaskScheduled = scheduledTaskIds.contains(t.id);
      final remainingSubs = t.subtasks
          .where((s) => !s.isCompleted && !scheduledSubtaskIds.contains(s.id))
          .toList();

      if (isTaskScheduled) return false;
      if (t.subtasks.isNotEmpty && remainingSubs.isEmpty) return false;
      return true;
    }).toList();

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark
          ? TempoTheme.surfaceElevated.withValues(alpha: 0.90)
          : Colors.white.withValues(alpha: 0.94),
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawer Header
          Row(
            children: [
              const Icon(CupertinoIcons.tray, color: TempoTheme.systemBlueDark, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Unscheduled Tasks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      CupertinoIcons.xmark,
                      size: 14,
                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Drag any item onto the timeline, or tap duration to quick-schedule.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider, height: 1),
          const SizedBox(height: 10),

          // Active Tasks List
          Expanded(
            child: activeTasks.isEmpty
                ? Center(
                    child: Text(
                      'No unscheduled tasks found.\nAll items are scheduled or completed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: activeTasks.length,
                    itemBuilder: (context, index) {
                      final task = activeTasks[index];
                      final uncompletedSubs = task.subtasks
                          .where((s) => !s.isCompleted && !scheduledSubtaskIds.contains(s.id))
                          .toList();
                      final effortBadge = task.badges.firstWhere(
                        (b) => b.categoryId == 'Effort',
                        orElse: () => const CustomBadge(
                          id: 'default',
                          label: 'Standard',
                          emoji: '',
                          colorHex: 0xFF0A84FF,
                          categoryId: 'Effort',
                        ),
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task Header (Draggable into timeline!)
                            Draggable<UnscheduledDragPayload>(
                              data: UnscheduledDragPayload(
                                title: task.title,
                                taskId: task.id,
                                colorHex: effortBadge.colorHex,
                                durationMinutes: 45,
                              ),
                              dragAnchorStrategy: (draggable, context, position) => const Offset(80, 20),
                              feedback: Material(
                                color: Colors.transparent,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Color(effortBadge.colorHex).withValues(alpha: 0.90),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 6)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(CupertinoIcons.clock, color: Colors.white, size: 12),
                                      const SizedBox(width: 6),
                                      Text(
                                        task.title,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text('45m', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                    ],
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (task.subjectCode.isNotEmpty)
                                    PillBadge(
                                      label: task.subjectCode,
                                      color: TempoTheme.systemBlueDark,
                                      isBracketStyle: true,
                                      isCompact: true,
                                      useNeutralStyle: true,
                                    ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.hand_draw, size: 11, color: TempoTheme.textMuted),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtasks list (Each also draggable into timeline!)
                            ...uncompletedSubs.map((sub) {
                              final durationMin = sub.estimatedMinutes ?? 30;

                              return Draggable<UnscheduledDragPayload>(
                                data: UnscheduledDragPayload(
                                  title: sub.title,
                                  taskId: task.id,
                                  subtaskId: sub.id,
                                  colorHex: effortBadge.colorHex,
                                  durationMinutes: durationMin,
                                ),
                                dragAnchorStrategy: (draggable, context, position) => const Offset(80, 20),
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Color(effortBadge.colorHex).withValues(alpha: 0.90),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                                      ],
                                    ),
                                    child: Text(
                                      sub.title,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(CupertinoIcons.circle, size: 11, color: TempoTheme.systemBlueDark),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          sub.title,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w400,
                                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${durationMin}m',
                                        style: TextStyle(fontSize: 9.5, color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildQuickSlotButton(
                                        label: 'Add',
                                        minutes: durationMin,
                                        task: task,
                                        sub: sub,
                                        color: effortBadge.colorHex,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSlotButton({
    required String label,
    required int minutes,
    required TaskItem task,
    required Subtask sub,
    required int color,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        final now = DateTime.now();
        final startTime = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          now.hour + 1,
          0,
        );
        final endTime = startTime.add(Duration(minutes: minutes));

        final block = TimeBlock(
          id: const Uuid().v4(),
          taskId: task.id,
          subtaskId: sub.id,
          title: '${sub.title} [${task.subjectCode}]',
          startTime: startTime,
          endTime: endTime,
          colorHex: color,
          isCompleted: false,
        );

        onScheduleBlock(block);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: TempoTheme.systemBlueDark.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Schedule',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: TempoTheme.systemBlueDark,
          ),
        ),
      ),
    );
  }
}
