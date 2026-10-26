import 'package:drift/drift.dart';
import '../../models/task_models.dart';
import 'connection.dart';
import 'database_seeder.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [BoardColumns, Tasks, Subtasks, Badges, TaskBadges, TimeBlocks])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await DatabaseSeeder.seed(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.toDoDate);
          }
        },
        beforeOpen: (details) async {
          await DatabaseSeeder.cleanSampleTasks(this);
        },
      );

  // ==========================================
  // COLUMNS
  // ==========================================
  Stream<List<BoardColumn>> watchColumns() {
    final query = select(boardColumns)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    return query.watch().map((rows) {
      return rows
          .map((r) => BoardColumn(
                id: r.id,
                title: r.title,
                emoji: r.emoji,
                order: r.orderIndex,
                wipLimit: r.wipLimit,
              ))
          .toList();
    });
  }

  Future<List<BoardColumn>> getAllColumns() async {
    final query = select(boardColumns)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]);
    final rows = await query.get();
    return rows
        .map((r) => BoardColumn(
              id: r.id,
              title: r.title,
              emoji: r.emoji,
              order: r.orderIndex,
              wipLimit: r.wipLimit,
            ))
        .toList();
  }

  Future<void> createColumn(BoardColumn column) async {
    await into(boardColumns).insert(
      BoardColumnsCompanion.insert(
        id: column.id,
        title: column.title,
        emoji: column.emoji,
        orderIndex: column.order,
        wipLimit: Value(column.wipLimit),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateColumnData(BoardColumn column) async {
    await (update(boardColumns)..where((t) => t.id.equals(column.id))).write(
      BoardColumnsCompanion(
        title: Value(column.title),
        emoji: Value(column.emoji),
        orderIndex: Value(column.order),
        wipLimit: Value(column.wipLimit),
      ),
    );
  }

  Future<void> deleteColumnById(String columnId) async {
    await transaction(() async {
      // Find all tasks in this column and delete them (or cascade)
      final tasksInCol = await (select(tasks)..where((t) => t.columnId.equals(columnId))).get();
      for (final t in tasksInCol) {
        await deleteTaskById(t.id);
      }
      await (delete(boardColumns)..where((t) => t.id.equals(columnId))).go();
    });
  }

  // ==========================================
  // BADGES
  // ==========================================
  Stream<List<CustomBadge>> watchBadges() {
    return select(badges).watch().map((rows) {
      return rows
          .map((r) => CustomBadge(
                id: r.id,
                label: r.label,
                emoji: r.emoji,
                colorHex: r.colorHex,
                categoryId: r.category,
              ))
          .toList();
    });
  }

  Future<List<CustomBadge>> getAllBadges() async {
    final rows = await select(badges).get();
    return rows
        .map((r) => CustomBadge(
              id: r.id,
              label: r.label,
              emoji: r.emoji,
              colorHex: r.colorHex,
              categoryId: r.category,
            ))
        .toList();
  }

  Future<void> createBadge(CustomBadge badge) async {
    await into(badges).insert(
      BadgesCompanion.insert(
        id: badge.id,
        label: badge.label,
        emoji: badge.emoji,
        colorHex: badge.colorHex,
        category: badge.categoryId,
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateBadgeData(CustomBadge badge) async {
    await (update(badges)..where((t) => t.id.equals(badge.id))).write(
      BadgesCompanion(
        label: Value(badge.label),
        emoji: Value(badge.emoji),
        colorHex: Value(badge.colorHex),
        category: Value(badge.categoryId),
      ),
    );
  }

  Future<void> deleteBadgeById(String badgeId) async {
    await (delete(badges)..where((t) => t.id.equals(badgeId))).go();
  }

  // ==========================================
  // TASKS & SUBTASKS (REACTIVE COMPOSITE STREAM)
  // ==========================================
  Stream<List<TaskItem>> watchTasksWithDetails() {
    return customSelect(
      'SELECT 1',
      readsFrom: {tasks, subtasks, badges, taskBadges},
    ).watch().asyncMap((_) async {
      final taskList = await (select(tasks)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
      final allSubtasks = await (select(subtasks)..orderBy([(t) => OrderingTerm(expression: t.orderIndex)])).get();
      final allBadges = await select(badges).get();
      final allTaskBadges = await select(taskBadges).get();

      final badgeMap = {
        for (final b in allBadges)
          b.id: CustomBadge(
            id: b.id,
            label: b.label,
            emoji: b.emoji,
            colorHex: b.colorHex,
            categoryId: b.category,
          )
      };

      final subtaskGroup = <String, List<Subtask>>{};
      for (final s in allSubtasks) {
        subtaskGroup.putIfAbsent(s.taskId, () => []).add(Subtask(
              id: s.id,
              taskId: s.taskId,
              title: s.title,
              isCompleted: s.isCompleted,
              estimatedMinutes: s.estimatedMinutes,
              orderIndex: s.orderIndex,
            ));
      }

      final taskBadgeGroup = <String, List<String>>{};
      for (final tb in allTaskBadges) {
        taskBadgeGroup.putIfAbsent(tb.taskId, () => []).add(tb.badgeId);
      }

      return taskList.map((t) {
        final badgeIds = taskBadgeGroup[t.id] ?? [];
        final taskBadgesList = badgeIds.map((bid) => badgeMap[bid]).whereType<CustomBadge>().toList();
        final taskSubs = subtaskGroup[t.id] ?? [];

        return TaskItem(
          id: t.id,
          title: t.title,
          subjectCode: t.subjectCode,
          columnId: t.columnId,
          badges: taskBadgesList,
          subtasks: taskSubs,
          dueDate: t.dueDate,
          toDoDate: t.toDoDate,
          createdAt: t.createdAt,
          order: t.orderIndex,
        );
      }).toList();
    });
  }

  Future<void> insertFullTask({
    required TaskItem task,
    required List<String> badgeIds,
  }) async {
    await transaction(() async {
      // 1. Insert task
      await into(tasks).insert(
        TasksCompanion.insert(
          id: task.id,
          title: task.title,
          subjectCode: task.subjectCode,
          columnId: task.columnId,
          dueDate: Value(task.dueDate),
          toDoDate: Value(task.toDoDate),
          createdAt: task.createdAt,
          orderIndex: task.order,
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 2. Insert badges
      await (delete(taskBadges)..where((t) => t.taskId.equals(task.id))).go();
      for (final bid in badgeIds) {
        await into(taskBadges).insert(
          TaskBadgesCompanion.insert(taskId: task.id, badgeId: bid),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // 3. Insert subtasks
      await (delete(subtasks)..where((t) => t.taskId.equals(task.id))).go();
      for (var i = 0; i < task.subtasks.length; i++) {
        final sub = task.subtasks[i];
        await into(subtasks).insert(
          SubtasksCompanion.insert(
            id: sub.id,
            taskId: task.id,
            title: sub.title,
            isCompleted: Value(sub.isCompleted),
            estimatedMinutes: Value(sub.estimatedMinutes),
            orderIndex: i,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> updateTaskDetails({
    required TaskItem task,
    required List<String> badgeIds,
  }) async {
    await transaction(() async {
      await (update(tasks)..where((t) => t.id.equals(task.id))).write(
        TasksCompanion(
          title: Value(task.title),
          subjectCode: Value(task.subjectCode),
          columnId: Value(task.columnId),
          dueDate: Value(task.dueDate),
          toDoDate: Value(task.toDoDate),
          orderIndex: Value(task.order),
        ),
      );

      // Update badges
      await (delete(taskBadges)..where((t) => t.taskId.equals(task.id))).go();
      for (final bid in badgeIds) {
        await into(taskBadges).insert(
          TaskBadgesCompanion.insert(taskId: task.id, badgeId: bid),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // Update subtasks
      await (delete(subtasks)..where((t) => t.taskId.equals(task.id))).go();
      for (var i = 0; i < task.subtasks.length; i++) {
        final sub = task.subtasks[i];
        await into(subtasks).insert(
          SubtasksCompanion.insert(
            id: sub.id,
            taskId: task.id,
            title: sub.title,
            isCompleted: Value(sub.isCompleted),
            estimatedMinutes: Value(sub.estimatedMinutes),
            orderIndex: i,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> deleteTaskById(String taskId) async {
    await transaction(() async {
      await (delete(subtasks)..where((t) => t.taskId.equals(taskId))).go();
      await (delete(taskBadges)..where((t) => t.taskId.equals(taskId))).go();
      await (update(timeBlocks)..where((t) => t.taskId.equals(taskId))).write(
        const TimeBlocksCompanion(
          taskId: Value(null),
          subtaskId: Value(null),
        ),
      );
      await (delete(tasks)..where((t) => t.id.equals(taskId))).go();
    });
  }

  Future<void> moveTaskColumn(String taskId, String newColumnId, int newOrder) async {
    await (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        columnId: Value(newColumnId),
        orderIndex: Value(newOrder),
      ),
    );
  }

  Future<void> reorderTask({
    required String taskId,
    required String targetColumnId,
    required int targetIndex,
  }) async {
    await transaction(() async {
      final existingTasks = await (select(tasks)
            ..where((t) => t.columnId.equals(targetColumnId))
            ..orderBy([(t) => OrderingTerm(expression: t.orderIndex)]))
          .get();

      final moving = await (select(tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();
      if (moving == null) return;

      final reordered = existingTasks.where((t) => t.id != taskId).toList();
      final clampedIndex = targetIndex.clamp(0, reordered.length);
      reordered.insert(clampedIndex, moving);

      for (var i = 0; i < reordered.length; i++) {
        await (update(tasks)..where((t) => t.id.equals(reordered[i].id))).write(
          TasksCompanion(
            columnId: Value(targetColumnId),
            orderIndex: Value(i),
          ),
        );
      }
    });
  }

  // ==========================================
  // BIDIRECTIONAL SUBTASK <-> TIMEBLOCK SYNC
  // ==========================================
  Future<void> toggleSubtask(String subtaskId, bool isCompleted) async {
    await transaction(() async {
      // 1. Update subtask
      await (update(subtasks)..where((t) => t.id.equals(subtaskId))).write(
        SubtasksCompanion(isCompleted: Value(isCompleted)),
      );

      // 2. Synchronize any linked TimeBlocks!
      await (update(timeBlocks)..where((t) => t.subtaskId.equals(subtaskId))).write(
        TimeBlocksCompanion(isCompleted: Value(isCompleted)),
      );
    });
  }

  // ==========================================
  // TIME BLOCKS
  // ==========================================
  Stream<List<TimeBlock>> watchAllTimeBlocks() {
    final query = select(timeBlocks)..orderBy([(t) => OrderingTerm(expression: t.startTime)]);
    return query.watch().map((rows) {
      return rows
          .map((r) => TimeBlock(
                id: r.id,
                taskId: r.taskId,
                subtaskId: r.subtaskId,
                title: r.title,
                startTime: r.startTime,
                endTime: r.endTime,
                colorHex: r.colorHex,
                isCompleted: r.isCompleted,
              ))
          .toList();
    });
  }

  Stream<List<TimeBlock>> watchTimeBlocksForDay(DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final query = select(timeBlocks)
      ..where((t) => t.startTime.isBiggerOrEqualValue(startOfDay) & t.startTime.isSmallerOrEqualValue(endOfDay))
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)]);

    return query.watch().map((rows) {
      return rows
          .map((r) => TimeBlock(
                id: r.id,
                taskId: r.taskId,
                subtaskId: r.subtaskId,
                title: r.title,
                startTime: r.startTime,
                endTime: r.endTime,
                colorHex: r.colorHex,
                isCompleted: r.isCompleted,
              ))
          .toList();
    });
  }

  Stream<List<TimeBlock>> watchTimeBlocksForRange(DateTime startDay, int daysCount) {
    final start = DateTime(startDay.year, startDay.month, startDay.day, 0, 0, 0);
    final endDay = startDay.add(Duration(days: (daysCount - 1).clamp(0, 30)));
    final end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);

    final query = select(timeBlocks)
      ..where((t) => t.startTime.isBiggerOrEqualValue(start) & t.startTime.isSmallerOrEqualValue(end))
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)]);

    return query.watch().map((rows) {
      return rows
          .map((r) => TimeBlock(
                id: r.id,
                taskId: r.taskId,
                subtaskId: r.subtaskId,
                title: r.title,
                startTime: r.startTime,
                endTime: r.endTime,
                colorHex: r.colorHex,
                isCompleted: r.isCompleted,
              ))
          .toList();
    });
  }

  Future<void> updateTimeBlockTime(String blockId, DateTime startTime, DateTime endTime) async {
    await (update(timeBlocks)..where((t) => t.id.equals(blockId))).write(
      TimeBlocksCompanion(
        startTime: Value(startTime),
        endTime: Value(endTime),
      ),
    );
  }

  Future<void> insertTimeBlock(TimeBlock block) async {
    await into(timeBlocks).insert(
      TimeBlocksCompanion.insert(
        id: block.id,
        taskId: Value(block.taskId),
        subtaskId: Value(block.subtaskId),
        title: block.title,
        startTime: block.startTime,
        endTime: block.endTime,
        colorHex: block.colorHex,
        isCompleted: Value(block.isCompleted),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> updateTimeBlockData(TimeBlock block) async {
    await (update(timeBlocks)..where((t) => t.id.equals(block.id))).write(
      TimeBlocksCompanion(
        taskId: Value(block.taskId),
        subtaskId: Value(block.subtaskId),
        title: Value(block.title),
        startTime: Value(block.startTime),
        endTime: Value(block.endTime),
        colorHex: Value(block.colorHex),
        isCompleted: Value(block.isCompleted),
      ),
    );
  }

  Future<void> deleteTimeBlockById(String blockId) async {
    await (delete(timeBlocks)..where((t) => t.id.equals(blockId))).go();
  }

  Future<void> toggleTimeBlock(String blockId, bool isCompleted) async {
    await transaction(() async {
      // 1. Update timeblock
      await (update(timeBlocks)..where((t) => t.id.equals(blockId))).write(
        TimeBlocksCompanion(isCompleted: Value(isCompleted)),
      );

      // 2. Fetch block to see if it links to a subtask
      final block = await (select(timeBlocks)..where((t) => t.id.equals(blockId))).getSingleOrNull();
      if (block != null && block.subtaskId != null) {
        // Synchronize linked subtask
        await (update(subtasks)..where((t) => t.id.equals(block.subtaskId!))).write(
          SubtasksCompanion(isCompleted: Value(isCompleted)),
        );
      }
    });
  }
}

