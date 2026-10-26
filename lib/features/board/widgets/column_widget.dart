import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';
import 'task_card.dart';

class ColumnWidget extends ConsumerStatefulWidget {
  final BoardColumn column;
  final List<TaskItem> tasks;
  final ValueChanged<TaskItem> onTaskTap;
  final ValueChanged<TaskItem> onTaskDelete;
  final void Function(TaskItem task, BoardColumn targetColumn, int targetIndex) onTaskReordered;

  const ColumnWidget({
    super.key,
    required this.column,
    required this.tasks,
    required this.onTaskTap,
    required this.onTaskDelete,
    required this.onTaskReordered,
  });

  @override
  ConsumerState<ColumnWidget> createState() => _ColumnWidgetState();
}

class _ColumnWidgetState extends ConsumerState<ColumnWidget> {
  int? _hoveredDropIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final column = widget.column;
    final tasks = widget.tasks;
    final wipLimit = column.wipLimit;
    final isWipExceeded = wipLimit != null && tasks.length > wipLimit;

    // Resizable width from provider
    final columnWidths = ref.watch(columnWidthsProvider);
    final currentWidth = columnWidths[column.id] ?? ColumnWidthsNotifier.defaultWidth;
    final accentColor = ref.watch(customAccentColorProvider);
    final customBg = ref.watch(customBackgroundProvider);
    final translucency = customBg.surfaceTranslucency;

    return Container(
      width: currentWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Stack(
        children: [
          GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.all(14),
            backgroundColor: isDark
                ? TempoTheme.surfaceDark.withValues(alpha: (translucency * 0.85).clamp(0.12, 0.90))
                : Colors.white.withValues(alpha: (translucency * 0.75).clamp(0.15, 0.88)),
            borderColor: Colors.transparent, // Tonal elevation: No heavy outer borders
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          column.title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      // Task Count / WIP Limit Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isWipExceeded
                              ? TempoTheme.pastelRose.withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          wipLimit != null ? '${tasks.length}/$wipLimit' : '${tasks.length}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isWipExceeded
                                ? TempoTheme.pastelRose
                                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Divider(
                  color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
                  height: 1,
                ),
                const SizedBox(height: 10),

                // Cards List with Fluid Apple Dragging & Reordering across entire column area
                Expanded(
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      // List of cards with slot insertion targets
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final task = tasks[index];
                            final showIndicatorAbove = _hoveredDropIndex == index;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Subtle insertion indicator when hovering above this task
                                if (showIndicatorAbove)
                                  Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentColor.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),

                                // Card with DragTarget detection for precision ordering
                                DragTarget<TaskItem>(
                                  onWillAcceptWithDetails: (details) {
                                    setState(() => _hoveredDropIndex = index);
                                    return true;
                                  },
                                  onLeave: (_) {
                                    if (_hoveredDropIndex == index) {
                                      setState(() => _hoveredDropIndex = null);
                                    }
                                  },
                                  onAcceptWithDetails: (details) {
                                    setState(() => _hoveredDropIndex = null);
                                    HapticFeedback.lightImpact();
                                    widget.onTaskReordered(details.data, column, index);
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    return Draggable<TaskItem>(
                                      data: task,
                                      dragAnchorStrategy: childDragAnchorStrategy,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: SizedBox(
                                          width: currentWidth - 28,
                                          child: TaskCard(task: task),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.20,
                                        child: TaskCard(task: task),
                                      ),
                                      child: TaskCard(
                                        task: task,
                                        onTap: () => widget.onTaskTap(task),
                                        onDelete: () => widget.onTaskDelete(task),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                          childCount: tasks.length,
                        ),
                      ),

                      // SliverFillRemaining fills ALL remaining empty vertical space in the column
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: DragTarget<TaskItem>(
                          onWillAcceptWithDetails: (details) {
                            setState(() => _hoveredDropIndex = tasks.length);
                            return true;
                          },
                          onLeave: (_) {
                            if (_hoveredDropIndex == tasks.length) {
                              setState(() => _hoveredDropIndex = null);
                            }
                          },
                          onAcceptWithDetails: (details) {
                            setState(() => _hoveredDropIndex = null);
                            HapticFeedback.lightImpact();
                            widget.onTaskReordered(details.data, column, tasks.length);
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = _hoveredDropIndex == tasks.length;
                            return Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 80),
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 8),
                              child: isHovered
                                  ? Container(
                                      height: 3,
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.8),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accentColor.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    )
                                  : (tasks.isEmpty
                                      ? Center(
                                          child: Text(
                                            candidateData.isNotEmpty ? 'Drop here' : 'No tasks',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.expand()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Column Resize Handle on the right edge
          Positioned(
            right: 0,
            top: 14,
            bottom: 14,
            width: 10,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: (details) {
                  final newWidth = currentWidth + details.delta.dx;
                  ref.read(columnWidthsProvider.notifier).setWidth(column.id, newWidth);
                },
                onDoubleTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(columnWidthsProvider.notifier).resetWidth(column.id);
                },
                child: Center(
                  child: Container(
                    width: 2.5,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
