import 'package:flutter/material.dart';

class Subtask {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int? estimatedMinutes;
  final int orderIndex;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
    this.estimatedMinutes,
    this.orderIndex = 0,
  });

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? isCompleted,
    int? estimatedMinutes,
    int? orderIndex,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}

class CustomBadge {
  final String id;
  final String label;
  final String emoji;
  final int colorHex;
  final String categoryId; // "Urgency", "Effort", "Context", "Custom"

  const CustomBadge({
    required this.id,
    required this.label,
    required this.emoji,
    required this.colorHex,
    required this.categoryId,
  });

  Color get color => Color(colorHex);

  CustomBadge copyWith({
    String? id,
    String? label,
    String? emoji,
    int? colorHex,
    String? categoryId,
  }) {
    return CustomBadge(
      id: id ?? this.id,
      label: label ?? this.label,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}

class BoardColumn {
  final String id;
  final String title;
  final String emoji;
  final int order;
  final int? wipLimit;

  const BoardColumn({
    required this.id,
    required this.title,
    required this.emoji,
    required this.order,
    this.wipLimit,
  });

  BoardColumn copyWith({
    String? id,
    String? title,
    String? emoji,
    int? order,
    int? wipLimit,
  }) {
    return BoardColumn(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      order: order ?? this.order,
      wipLimit: wipLimit ?? this.wipLimit,
    );
  }
}

class TaskItem {
  final String id;
  final String title;
  final String subjectCode; // e.g. "ENG", "SCI", "RSH"
  final String columnId;
  final List<CustomBadge> badges;
  final List<Subtask> subtasks;
  final DateTime? dueDate; // Hard deadline
  final DateTime? toDoDate; // Target / planned date to work on task
  final DateTime createdAt;
  final int order;
  final bool isCompleted;

  const TaskItem({
    required this.id,
    required this.title,
    required this.subjectCode,
    required this.columnId,
    this.badges = const [],
    this.subtasks = const [],
    this.dueDate,
    this.toDoDate,
    required this.createdAt,
    this.order = 0,
    this.isCompleted = false,
  });

  int get totalSubtasks => subtasks.length;
  int get completedSubtasks => subtasks.where((s) => s.isCompleted).length;

  /// Returns 0.0 to 1.0 representing smooth task completion progress.
  double get progressRatio {
    if (subtasks.isEmpty) {
      return isCompleted ? 1.0 : 0.0;
    }
    if (isCompleted) return 1.0;
    return totalSubtasks > 0 ? (completedSubtasks / totalSubtasks) : 0.0;
  }

  double get progress => progressRatio;

  bool get isTaskCompleted {
    if (subtasks.isEmpty) {
      return isCompleted;
    }
    return isCompleted || (subtasks.isNotEmpty && completedSubtasks == totalSubtasks);
  }

  bool get isAllCompleted => isTaskCompleted;

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  String get countdownText {
    if (dueDate == null) return '';
    final now = DateTime.now();
    final difference = dueDate!.difference(now);

    if (difference.isNegative) {
      final days = difference.inDays.abs();
      if (days == 0) return 'Overdue today';
      return '$days d overdue';
    } else {
      if (difference.inDays == 0) {
        final hours = difference.inHours;
        if (hours <= 0) return '${difference.inMinutes}m left';
        return '${hours}h left';
      } else {
        return '${difference.inDays}d left';
      }
    }
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? subjectCode,
    String? columnId,
    List<CustomBadge>? badges,
    List<Subtask>? subtasks,
    DateTime? dueDate,
    DateTime? toDoDate,
    DateTime? createdAt,
    int? order,
    bool? isCompleted,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectCode: subjectCode ?? this.subjectCode,
      columnId: columnId ?? this.columnId,
      badges: badges ?? this.badges,
      subtasks: subtasks ?? this.subtasks,
      dueDate: dueDate ?? this.dueDate,
      toDoDate: toDoDate ?? this.toDoDate,
      createdAt: createdAt ?? this.createdAt,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class TimeBlock {
  final String id;
  final String? taskId;
  final String? subtaskId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int colorHex;
  final bool isCompleted;

  const TimeBlock({
    required this.id,
    this.taskId,
    this.subtaskId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.colorHex,
    this.isCompleted = false,
  });

  Color get color => Color(colorHex);

  Duration get duration => endTime.difference(startTime);

  TimeBlock copyWith({
    String? id,
    String? taskId,
    String? subtaskId,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? colorHex,
    bool? isCompleted,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      subtaskId: subtaskId ?? this.subtaskId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorHex: colorHex ?? this.colorHex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

