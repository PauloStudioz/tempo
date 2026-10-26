import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class TaskCard extends ConsumerStatefulWidget {
  final TaskItem task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onDelete,
  });

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  // Track recently toggled subtask id for fluid scale animation
  String? _animatingSubtaskId;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final urgencyAndEffortBadges = task.badges
        .where((b) => b.categoryId != 'Context')
        .toList();
    final contextBadges = task.badges
        .where((b) => b.categoryId == 'Context')
        .toList();

    final isOverdue = task.isOverdue;
    final progress = task.progress;
    final translucency = ref.watch(customBackgroundProvider).surfaceTranslucency;

    return GlassContainer(
      borderRadius: 16,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18), // Increased whitespace & padding
      backgroundColor: isDark
          ? TempoTheme.surfaceElevated.withValues(alpha: (translucency * 1.15).clamp(0.15, 0.96))
          : Colors.white.withValues(alpha: (translucency * 1.10).clamp(0.18, 0.94)),
      borderColor: Colors.transparent, // Tonal elevation: No heavy 1px prison-cell borders
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row: Tamed Neutral Metadata Badges (No Jira Rainbow) + Delete
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    // Scope Code Bracket Tag
                    if (task.subjectCode.isNotEmpty)
                      PillBadge(
                        label: task.subjectCode,
                        color: TempoTheme.systemBlueDark,
                        isBracketStyle: true,
                        isCompact: true,
                        useNeutralStyle: true,
                      ),
                    // Neutral Attribute Badges with subtle accent dot
                    ...urgencyAndEffortBadges.map((b) => PillBadge(
                          label: b.label,
                          color: b.color,
                          isCompact: true,
                          showDot: true,
                          useNeutralStyle: true,
                        )),
                    ...contextBadges.map((b) => PillBadge(
                          label: b.label,
                          color: b.color,
                          isCompact: true,
                          useNeutralStyle: true,
                        )),
                  ],
                ),
              ),
              if (widget.onDelete != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onDelete?.call();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 13,
                        color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Body: Bold Readable Task Title
          Text(
            task.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.25,
              color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
              height: 1.35,
            ),
          ),

          // 3. Inline Subtasks Checklist with Smooth Fluid Micro-Animations
          if (task.subtasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                children: task.subtasks.map((sub) {
                  final isAnimating = _animatingSubtaskId == sub.id;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Fluid Animated Checkbox Pop
                        GestureDetector(
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            setState(() => _animatingSubtaskId = sub.id);
                            final db = ref.read(databaseProvider);
                            await db.toggleSubtask(sub.id, !sub.isCompleted);
                            if (mounted) {
                              Future.delayed(const Duration(milliseconds: 250), () {
                                if (mounted) setState(() => _animatingSubtaskId = null);
                              });
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedScale(
                            scale: isAnimating ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutBack,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: sub.isCompleted
                                    ? TempoTheme.pastelMint
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: sub.isCompleted
                                      ? TempoTheme.pastelMint
                                      : (isDark
                                          ? TempoTheme.textMuted.withValues(alpha: 0.5)
                                          : TempoTheme.lightTextMuted.withValues(alpha: 0.5)),
                                  width: 1.3,
                                ),
                              ),
                              child: sub.isCompleted
                                  ? const Center(
                                      child: Icon(
                                        Icons.check,
                                        size: 11,
                                        color: Colors.black,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Strikethrough & color fade animation
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: sub.isCompleted
                                  ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                                  : (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary),
                              decoration: sub.isCompleted
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                            ),
                            child: Text(sub.title),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // 4. Footer Row: To-Do Date, Due Date, Dynamic Countdown, Subtask Ratio Chip
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (task.toDoDate != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.calendar,
                      size: 11.5,
                      color: isDark ? const Color(0xFF64D2FF) : const Color(0xFF007AFF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'To-Do: ${DateFormatter.formatMonthDay(task.toDoDate)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64D2FF) : const Color(0xFF007AFF),
                      ),
                    ),
                  ],
                ),
              if (task.dueDate != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.flag,
                      size: 11,
                      color: isOverdue
                          ? TempoTheme.pastelRose
                          : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${DateFormatter.formatMonthDay(task.dueDate)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: isOverdue
                            ? TempoTheme.pastelRose
                            : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? TempoTheme.pastelRose.withValues(alpha: 0.12)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.countdownText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: isOverdue
                          ? TempoTheme.pastelRose
                          : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                    ),
                  ),
                ),
              ],
              if (task.subtasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.isAllCompleted
                        ? TempoTheme.pastelMint.withValues(alpha: 0.14)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        task.isAllCompleted
                            ? CupertinoIcons.checkmark_circle_fill
                            : CupertinoIcons.checkmark_circle,
                        size: 11,
                        color: task.isAllCompleted
                            ? TempoTheme.pastelMint
                            : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.completedSubtasks}/${task.totalSubtasks}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: task.isAllCompleted
                              ? TempoTheme.pastelMint
                              : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // 5. Animated Visual Progress Bar (Smooth TweenAnimationBuilder)
          if (task.subtasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 3,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: progress),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: value,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        value >= 1.0
                            ? TempoTheme.pastelMint
                            : (value > 0.5 ? TempoTheme.systemBlueDark : TempoTheme.pastelHoney),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
