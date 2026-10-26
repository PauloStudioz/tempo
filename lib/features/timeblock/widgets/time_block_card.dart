import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task_models.dart';

class TimeBlockCard extends StatelessWidget {
  final TimeBlock block;
  final DateTime? displayStartTime;
  final DateTime? displayEndTime;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final void Function(Offset position)? onContextMenu;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final GestureDragStartCallback? onResizeStart;
  final GestureDragUpdateCallback? onResizeUpdate;
  final GestureDragEndCallback? onResizeEnd;

  const TimeBlockCard({
    super.key,
    required this.block,
    this.displayStartTime,
    this.displayEndTime,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    this.onContextMenu,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = block.color;
    final isDone = block.isCompleted;

    final start = displayStartTime ?? block.startTime;
    final end = displayEndTime ?? block.endTime;

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: (details) => onContextMenu?.call(details.globalPosition),
      onVerticalDragStart: onDragStart,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? Color.alphaBlend(baseColor.withValues(alpha: isDone ? 0.18 : 0.40), const Color(0xF21C1D21))
                : Color.alphaBlend(baseColor.withValues(alpha: isDone ? 0.15 : 0.32), const Color(0xF7FFFFFF)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isDone
                  ? baseColor.withValues(alpha: 0.35)
                  : baseColor.withValues(alpha: 0.85),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxHeight < 52;

              if (isVeryCompact) {
                return Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onToggle();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isDone ? TempoTheme.pastelMint : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isDone
                                  ? TempoTheme.pastelMint
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.5)),
                              width: 1.1,
                            ),
                          ),
                          child: isDone
                              ? const Center(
                                  child: Icon(Icons.check, size: 8, color: Colors.black),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${DateFormatter.formatRange(start, end)} • ${block.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDone
                                ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                                : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onDelete();
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 10,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ClipRect(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    // Header Row: Checkbox + Time range + Delete
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onToggle();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: isDone ? TempoTheme.pastelMint : Colors.transparent,
                              borderRadius: BorderRadius.circular(3.5),
                              border: Border.all(
                                color: isDone
                                    ? TempoTheme.pastelMint
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.6)
                                        : Colors.black.withValues(alpha: 0.5)),
                                width: 1.2,
                              ),
                            ),
                            child: isDone
                                ? const Center(
                                    child: Icon(Icons.check, size: 8.5, color: Colors.black),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            DateFormatter.formatRange(start, end),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDone
                                  ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                                  : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onDelete();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(1.0),
                              child: Icon(
                                CupertinoIcons.xmark,
                                size: 10,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1.5),
                    // Title
                    Expanded(
                      child: Text(
                        block.title,
                        maxLines: constraints.maxHeight >= 72 ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                              : (isDark ? Colors.white : const Color(0xFF1C1C1E)),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                          height: 1.15,
                        ),
                      ),
                    ),
                    // Bottom Resize Handle
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: onResizeStart,
                      onVerticalDragUpdate: onResizeUpdate,
                      onVerticalDragEnd: onResizeEnd,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 3.5,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
