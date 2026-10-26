import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../providers/tempo_providers.dart';
import '../widgets/column_widget.dart';
import '../widgets/task_edit_dialog.dart';

enum TaskStatusFilter { all, active, completed }

class BoardView extends ConsumerStatefulWidget {
  const BoardView({super.key});

  @override
  ConsumerState<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends ConsumerState<BoardView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  TaskStatusFilter _statusFilter = TaskStatusFilter.all;
  String? _selectedBadgeFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columnsAsync = ref.watch(columnsStreamProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final badgesAsync = ref.watch(badgesStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final badges = badgesAsync.value ?? [];
    final activeBadge = badges.where((b) => b.id == _selectedBadgeFilter).firstOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streamlined Apple HIG Top Bar (Segmented Control + Filter Popover + Search)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Board',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // macOS Style Segmented Control (All / Active / Completed)
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSegmentButton('All', TaskStatusFilter.all, isDark),
                        _buildSegmentButton('Active', TaskStatusFilter.active, isDark),
                        _buildSegmentButton('Completed', TaskStatusFilter.completed, isDark),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Contextual Filter Popover / Dropdown
                  PopupMenuButton<String?>(
                    tooltip: 'Filter by attribute',
                    onSelected: (val) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedBadgeFilter = val);
                    },
                    color: isDark ? TempoTheme.surfaceElevated : TempoTheme.lightSurfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem<String?>(
                          value: null,
                          child: Text('All Attributes', style: TextStyle(fontSize: 12.5)),
                        ),
                        const PopupMenuDivider(height: 1),
                        ...badges.map((b) => PopupMenuItem<String?>(
                              value: b.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: b.color,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      b.label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _selectedBadgeFilter == b.id
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  if (_selectedBadgeFilter == b.id)
                                    const Icon(CupertinoIcons.checkmark, size: 13, color: TempoTheme.systemBlueDark),
                                ],
                              ),
                            )),
                      ];
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _selectedBadgeFilter != null
                            ? (isDark
                                ? TempoTheme.systemBlueDark.withValues(alpha: 0.15)
                                : TempoTheme.systemBlue.withValues(alpha: 0.12))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.line_horizontal_3_decrease,
                            size: 13,
                            color: _selectedBadgeFilter != null
                                ? TempoTheme.systemBlueDark
                                : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                          ),
                          if (activeBadge != null) ...[
                            const SizedBox(width: 5),
                            Text(
                              activeBadge.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: TempoTheme.systemBlueDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _selectedBadgeFilter = null),
                              child: const Icon(CupertinoIcons.xmark, size: 10, color: TempoTheme.systemBlueDark),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Clean Minimalist Search Input
                  SizedBox(
                    width: 190,
                    height: 30,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search tasks...',
                        hintStyle: TextStyle(
                          color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                          fontSize: 11.5,
                        ),
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          size: 13,
                          color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 26),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Icon(
                                  CupertinoIcons.clear_circled_solid,
                                  size: 13,
                                  color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: TempoTheme.systemBlueDark, width: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Horizontal Resizable Columns Grid with Fluid Apple Physics
            Expanded(
              child: columnsAsync.when(
                data: (columns) {
                  final allTasks = tasksAsync.value ?? [];

                  // Apply search, status, and attribute filters
                  final filteredTasks = allTasks.where((task) {
                    final matchesSearch = _searchQuery.isEmpty ||
                        task.title.toLowerCase().contains(_searchQuery) ||
                        task.subjectCode.toLowerCase().contains(_searchQuery) ||
                        task.subtasks.any((s) => s.title.toLowerCase().contains(_searchQuery));

                    final matchesBadge = _selectedBadgeFilter == null ||
                        task.badges.any((b) => b.id == _selectedBadgeFilter);

                    final matchesStatus = switch (_statusFilter) {
                      TaskStatusFilter.all => true,
                      TaskStatusFilter.active => !task.isAllCompleted,
                      TaskStatusFilter.completed => task.isAllCompleted,
                    };

                    return matchesSearch && matchesBadge && matchesStatus;
                  }).toList();

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    itemCount: columns.length,
                    itemBuilder: (context, index) {
                      final col = columns[index];
                      final colTasks = filteredTasks.where((t) => t.columnId == col.id).toList();

                      return ColumnWidget(
                        column: col,
                        tasks: colTasks,
                        onTaskTap: (task) {
                          TaskEditDialog.show(context, initialTask: task);
                        },
                        onTaskDelete: (task) async {
                          final db = ref.read(databaseProvider);
                          await db.deleteTaskById(task.id);
                        },
                        onTaskReordered: (task, targetCol, targetIndex) async {
                          final db = ref.read(databaseProvider);
                          await db.reorderTask(
                            taskId: task.id,
                            targetColumnId: targetCol.id,
                            targetIndex: targetIndex,
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: TempoTheme.systemBlueDark, strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Text('Error: $err', style: const TextStyle(color: TempoTheme.pastelRose)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, TaskStatusFilter filter, bool isDark) {
    final isSelected = _statusFilter == filter;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _statusFilter = filter);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary)
                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
          ),
        ),
      ),
    );
  }
}
