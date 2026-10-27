import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class TaskEditDialog extends ConsumerStatefulWidget {
  final TaskItem? initialTask;
  final String? defaultColumnId;

  const TaskEditDialog({
    super.key,
    this.initialTask,
    this.defaultColumnId,
  });

  static Future<void> show(
    BuildContext context, {
    TaskItem? initialTask,
    String? defaultColumnId,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (ctx) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: Material(
              color: Colors.transparent,
              child: TaskEditDialog(
                initialTask: initialTask,
                defaultColumnId: defaultColumnId,
              ),
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: Material(
                color: Colors.transparent,
                child: TaskEditDialog(
                  initialTask: initialTask,
                  defaultColumnId: defaultColumnId,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  final _uuid = const Uuid();
  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _newSubtaskController;

  String? _selectedColumnId;
  DateTime? _dueDate;
  DateTime? _toDoDate;
  final Set<String> _selectedBadgeIds = {};
  final List<Subtask> _subtasks = [];

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;

    _titleController = TextEditingController(text: task?.title ?? '');
    _subjectController = TextEditingController(text: task?.subjectCode ?? 'ENG');
    _newSubtaskController = TextEditingController();

    _selectedColumnId = task?.columnId ?? widget.defaultColumnId;
    _dueDate = task?.dueDate;
    _toDoDate = task?.toDoDate;

    if (task != null) {
      _selectedBadgeIds.addAll(task.badges.map((b) => b.id));
      _subtasks.addAll(task.subtasks);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  Color _getColumnColor(BoardColumn col, int index) {
    final lower = col.title.toLowerCase();
    if (lower.contains('now') || lower.contains('doing') || lower.contains('active')) {
      return TempoTheme.pastelSky;
    } else if (lower.contains('soon') || lower.contains('next') || lower.contains('week')) {
      return TempoTheme.pastelHoney;
    } else if (lower.contains('later') || lower.contains('plan') || lower.contains('backlog')) {
      return TempoTheme.pastelLilac;
    } else if (lower.contains('done') || lower.contains('completed')) {
      return TempoTheme.pastelMint;
    }
    final palette = [
      TempoTheme.pastelSky,
      TempoTheme.pastelHoney,
      TempoTheme.pastelLilac,
      TempoTheme.pastelMint,
      TempoTheme.pastelRose,
      TempoTheme.pastelSlate,
      TempoTheme.pastelIndigo,
    ];
    return palette[index % palette.length];
  }

  void _addSubtask() {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _subtasks.add(
        Subtask(
          id: _uuid.v4(),
          taskId: widget.initialTask?.id ?? '',
          title: title,
          isCompleted: false,
          estimatedMinutes: 30,
          orderIndex: _subtasks.length,
        ),
      );
      _newSubtaskController.clear();
    });
  }

  void _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    final columns = ref.read(columnsStreamProvider).value ?? [];
    final columnId = _selectedColumnId ?? (columns.isNotEmpty ? columns.first.id : 'col_doing_now');
    final subjectCode = _subjectController.text.trim().toUpperCase();

    final taskId = widget.initialTask?.id ?? _uuid.v4();
    final db = ref.read(databaseProvider);

    final finalSubtasks = _subtasks.map((s) => s.copyWith(taskId: taskId)).toList();

    final taskItem = TaskItem(
      id: taskId,
      title: title,
      subjectCode: subjectCode,
      columnId: columnId,
      toDoDate: _toDoDate,
      dueDate: _dueDate,
      createdAt: widget.initialTask?.createdAt ?? DateTime.now(),
      order: widget.initialTask?.order ?? 0,
      subtasks: finalSubtasks,
    );

    if (widget.initialTask == null) {
      await db.insertFullTask(task: taskItem, badgeIds: _selectedBadgeIds.toList());
    } else {
      await db.updateTaskDetails(task: taskItem, badgeIds: _selectedBadgeIds.toList());
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final columnsAsync = ref.watch(columnsStreamProvider);
    final badgesAsync = ref.watch(badgesStreamProvider);

    final columns = columnsAsync.value ?? [];
    final badges = badgesAsync.value ?? [];

    // Group badges by category if present
    final categoryOrder = ['Urgency', 'Effort', 'Context'];
    final categoryMap = <String, List<CustomBadge>>{};
    for (final badge in badges) {
      categoryMap.putIfAbsent(badge.categoryId, () => []).add(badge);
    }
    final sortedCategories = categoryMap.keys.toList()
      ..sort((a, b) {
        final idxA = categoryOrder.indexOf(a);
        final idxB = categoryOrder.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xCC161820) : const Color(0xF2FFFFFF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Hugs content tightly — removes empty void
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Text(
                      widget.initialTask == null ? 'New Task' : 'Edit Task',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                          ),
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
                const SizedBox(height: 12),
                Divider(
                  color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
                  height: 1,
                ),
                const SizedBox(height: 12),

                // Form Body (Flexible — never wastes vertical empty space)
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Input
                        Text(
                          'Title',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            fontSize: 13.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Task description...',
                            hintStyle: TextStyle(
                              color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                                width: 0.7,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                                width: 0.7,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: TempoTheme.pastelSky, width: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Scope Code & Due Date Row
                        Row(
                          children: [
                            // Scope Code
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scope Code',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextField(
                                    controller: _subjectController,
                                    style: const TextStyle(
                                      color: TempoTheme.pastelSky,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: 0.4,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'ENG',
                                      hintStyle: TextStyle(
                                        color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                      ),
                                      filled: true,
                                      fillColor: TempoTheme.pastelSky.withValues(alpha: 0.07),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: TempoTheme.pastelSky.withValues(alpha: 0.25), width: 0.8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: TempoTheme.pastelSky.withValues(alpha: 0.25), width: 0.8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: TempoTheme.pastelSky, width: 1.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // To-Do Date Picker (Target date)
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'To-Do Date',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _toDoDate ?? DateTime.now(),
                                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: isDark ? TempoTheme.darkTheme : TempoTheme.lightTheme,
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() => _toDoDate = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _toDoDate != null
                                            ? TempoTheme.pastelSky.withValues(alpha: 0.12)
                                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _toDoDate != null
                                              ? TempoTheme.pastelSky.withValues(alpha: 0.45)
                                              : (isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.calendar,
                                            size: 13,
                                            color: _toDoDate != null
                                                ? TempoTheme.pastelSky
                                                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              _toDoDate != null ? DateFormatter.formatMonthDay(_toDoDate) : 'Plan date',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: _toDoDate != null ? FontWeight.w600 : FontWeight.w400,
                                                color: _toDoDate != null
                                                    ? TempoTheme.pastelSky
                                                    : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_toDoDate != null)
                                            GestureDetector(
                                              onTap: () => setState(() => _toDoDate = null),
                                              child: Icon(
                                                CupertinoIcons.xmark_circle_fill,
                                                size: 13,
                                                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Due Date / Deadline Picker
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due Date',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 2)),
                                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: isDark ? TempoTheme.darkTheme : TempoTheme.lightTheme,
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() => _dueDate = picked);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _dueDate != null
                                            ? TempoTheme.pastelHoney.withValues(alpha: 0.12)
                                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _dueDate != null
                                              ? TempoTheme.pastelHoney.withValues(alpha: 0.45)
                                              : (isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.flag,
                                            size: 13,
                                            color: _dueDate != null
                                                ? TempoTheme.pastelHoney
                                                : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              _dueDate != null ? DateFormatter.formatMonthDay(_dueDate) : 'Deadline',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: _dueDate != null ? FontWeight.w600 : FontWeight.w400,
                                                color: _dueDate != null
                                                    ? TempoTheme.pastelHoney
                                                    : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_dueDate != null)
                                            GestureDetector(
                                              onTap: () => setState(() => _dueDate = null),
                                              child: Icon(
                                                CupertinoIcons.xmark_circle_fill,
                                                size: 13,
                                                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Column Horizon (Color-coded options!)
                        Text(
                          'Column',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: columns.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final col = entry.value;
                              final isSelected = (_selectedColumnId ?? columns.firstOrNull?.id) == col.id;
                              final colColor = _getColumnColor(col, idx);

                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _selectedColumnId = col.id);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? colColor.withValues(alpha: 0.22)
                                          : colColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? colColor.withValues(alpha: 0.90)
                                            : colColor.withValues(alpha: 0.30),
                                        width: isSelected ? 1.2 : 0.8,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: colColor.withValues(alpha: 0.25),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 5),
                                            child: Icon(CupertinoIcons.checkmark, size: 12, color: colColor),
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(right: 5),
                                            child: Container(
                                              width: 5.5,
                                              height: 5.5,
                                              decoration: BoxDecoration(
                                                color: colColor.withValues(alpha: 0.85),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          col.title,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? colColor : colColor.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Attributes / Badges (Color-coded options!)
                        Text(
                          'Attributes',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (sortedCategories.isNotEmpty) ...[
                          ...sortedCategories.map((cat) {
                            final catBadges = categoryMap[cat] ?? [];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: catBadges.map((badge) {
                                  final isSelected = _selectedBadgeIds.contains(badge.id);
                                  final bColor = badge.color;

                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (isSelected) {
                                          _selectedBadgeIds.remove(badge.id);
                                        } else {
                                          _selectedBadgeIds.add(badge.id);
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      curve: Curves.easeOutCubic,
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? bColor.withValues(alpha: 0.26)
                                            : bColor.withValues(alpha: 0.09),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? bColor : bColor.withValues(alpha: 0.35),
                                          width: isSelected ? 1.2 : 0.8,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: bColor.withValues(alpha: 0.25),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4.5),
                                              child: Icon(CupertinoIcons.checkmark, size: 10.5, color: bColor),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(right: 4.5),
                                              child: Container(
                                                width: 5,
                                                height: 5,
                                                decoration: BoxDecoration(
                                                  color: bColor.withValues(alpha: 0.85),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            badge.label,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              color: isSelected ? bColor : bColor.withValues(alpha: 0.90),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),
                        ] else ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: badges.map((badge) {
                              final isSelected = _selectedBadgeIds.contains(badge.id);
                              final bColor = badge.color;

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (isSelected) {
                                      _selectedBadgeIds.remove(badge.id);
                                    } else {
                                      _selectedBadgeIds.add(badge.id);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? bColor.withValues(alpha: 0.26)
                                        : bColor.withValues(alpha: 0.09),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? bColor : bColor.withValues(alpha: 0.35),
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4.5),
                                          child: Icon(CupertinoIcons.checkmark, size: 10.5, color: bColor),
                                        )
                                      else
                                        Padding(
                                          padding: const EdgeInsets.only(right: 4.5),
                                          child: Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: bColor.withValues(alpha: 0.85),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                      Text(
                                        badge.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                          color: isSelected ? bColor : bColor.withValues(alpha: 0.90),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Subtasks Section
                        Row(
                          children: [
                            Text(
                              'Subtasks',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: TempoTheme.pastelSky.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_subtasks.length}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: TempoTheme.pastelSky,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Subtask Add Input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newSubtaskController,
                                onSubmitted: (_) => _addSubtask(),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Add a subtask...',
                                  hintStyle: TextStyle(
                                    color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                    fontSize: 12,
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.white.withValues(alpha: 0.04)
                                      : Colors.black.withValues(alpha: 0.03),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                                      width: 0.6,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                                      width: 0.6,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: TempoTheme.pastelSky, width: 0.8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _addSubtask,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: TempoTheme.pastelSky.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: TempoTheme.pastelSky.withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Icon(
                                  CupertinoIcons.plus,
                                  size: 16,
                                  color: TempoTheme.pastelSky,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Subtasks List
                        if (_subtasks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ..._subtasks.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final sub = entry.value;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.06),
                                  width: 0.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _subtasks[idx] = sub.copyWith(isCompleted: !sub.isCompleted);
                                      });
                                    },
                                    child: Icon(
                                      sub.isCompleted
                                          ? CupertinoIcons.checkmark_circle_fill
                                          : CupertinoIcons.circle,
                                      size: 15,
                                      color: sub.isCompleted
                                          ? TempoTheme.pastelMint
                                          : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      sub.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: sub.isCompleted
                                            ? (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted)
                                            : (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary),
                                        decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _subtasks.removeAt(idx);
                                      });
                                    },
                                    child: Icon(
                                      CupertinoIcons.xmark,
                                      size: 12,
                                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Divider(
                  color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
                  height: 1,
                ),
                const SizedBox(height: 12),

                // Action Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _saveTask,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TempoTheme.pastelSky,
                        foregroundColor: const Color(0xFF0F172A), // Dark contrast on pastel sky
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.initialTask == null ? 'Create' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
