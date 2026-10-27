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
  double _lastProgress = 0.0;

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
    final animBegin = _lastProgress;
    _lastProgress = progress;
    final translucency = ref.watch(customBackgroundProvider).surfaceTranslucency;
    final accentColor = ref.watch(customAccentColorProvider);
    final animationsEnabled = ref.watch(animationsEnabledProvider);

    return RepaintBoundary(
      child: GlassContainer(
        borderRadius: 16,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18), // Increased whitespace & padding
        blur: 0, // High-performance: column provides glass backdrop, card uses crisp surface tint
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

          // 2. Body: Circular Gradual Fill Checkbox + Bold Readable Task Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: TaskCircularCheckbox(
                  progress: task.progressRatio,
                  isCompleted: task.isTaskCompleted,
                  accentColor: accentColor,
                  isDark: isDark,
                  animationsEnabled: animationsEnabled,
                  onToggle: () async {
                    final db = ref.read(databaseProvider);
                    await db.toggleTaskCompleted(task.id, !task.isTaskCompleted);
                  },
                ),
              ),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.25,
                    color: task.isTaskCompleted
                        ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                        : (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary),
                    decoration: task.isTaskCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                    height: 1.35,
                  ),
                ),
              ),
            ],
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
                      color: isDark ? TempoTheme.pastelSky : TempoTheme.systemBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'To-Do: ${DateFormatter.formatMonthDay(task.toDoDate)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? TempoTheme.pastelSky : TempoTheme.systemBlue,
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
                  tween: Tween<double>(begin: animBegin, end: progress),
                  duration: animationsEnabled ? const Duration(milliseconds: 350) : Duration.zero,
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
    ),
  );
}
}

/// Circular Checkbox that smoothly gradually fills up as subtasks are completed,
/// or directly toggles normal tasks with or without subtasks.
class TaskCircularCheckbox extends StatelessWidget {
  final double progress;
  final bool isCompleted;
  final Color accentColor;
  final bool isDark;
  final bool animationsEnabled;
  final VoidCallback onToggle;

  const TaskCircularCheckbox({
    super.key,
    required this.progress,
    required this.isCompleted,
    required this.accentColor,
    required this.isDark,
    required this.animationsEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = isCompleted ? 1.0 : progress.clamp(0.0, 1.0);
    final isDone = effectiveProgress >= 0.999;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onToggle();
        },
        child: SizedBox(
          width: 22,
          height: 22,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: effectiveProgress),
            duration: animationsEnabled ? const Duration(milliseconds: 280) : Duration.zero,
            curve: Curves.easeOutCubic,
            builder: (context, animVal, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: _CircularCheckboxPainter(
                      progress: animVal,
                      accentColor: isDone ? TempoTheme.pastelMint : accentColor,
                      isDark: isDark,
                      isDone: isDone,
                    ),
                  ),
                  if (animVal >= 0.95)
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: animationsEnabled ? const Duration(milliseconds: 180) : Duration.zero,
                      curve: Curves.elasticOut,
                      builder: (context, scale, _) {
                        return Transform.scale(
                          scale: scale,
                          child: const Icon(
                            CupertinoIcons.checkmark,
                            size: 11,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CircularCheckboxPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isDark;
  final bool isDone;

  const _CircularCheckboxPainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
    required this.isDone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 2.5) / 2;

    // 1. Background Ring Track
    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Full fill when completed (1.0)
    if (isDone) {
      final fillPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
      return;
    }

    // 3. Smooth progressive arc fill when 0 < progress < 1.0
    if (progress > 0.01) {
      final progressPaint = Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      // Start from 12 o'clock (-pi / 2) and sweep clockwise
      const startAngle = -3.141592653589793 / 2;
      final sweepAngle = 2 * 3.141592653589793 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );

      // Subtle translucent inner fill corresponding to progress
      final softFillPaint = Paint()
        ..color = accentColor.withValues(alpha: (progress * 0.16).clamp(0.04, 0.20))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius - 1, softFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularCheckboxPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isDone != isDone;
  }
}
