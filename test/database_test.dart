import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/core/database/app_database.dart';
import 'package:tempo/core/database/connection.dart';
import 'package:tempo/core/database/database_seeder.dart';
import 'package:tempo/models/task_models.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Drift SQLite Database & Sync Tests', () {
    test('Seeded columns and badges load correctly', () async {
      final columns = await db.getAllColumns();
      expect(columns.length, equals(3));
      expect(columns.any((c) => c.title == 'Doing Now'), isTrue);

      final badges = await db.getAllBadges();
      expect(badges.length, greaterThanOrEqualTo(8));
      expect(badges.any((b) => b.label == 'ASAP'), isTrue);
      expect(badges.any((b) => b.label == 'High Effort'), isTrue);
    });

    test('Insert and fetch full task with subtasks and badges', () async {
      final taskId = 'task_test_1';
      final now = DateTime.now();

      final task = TaskItem(
        id: taskId,
        title: 'Complete Software Architecture Plan',
        subjectCode: 'CS',
        columnId: 'col_doing_now',
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now,
        subtasks: [
          Subtask(id: 'sub_t_1', taskId: taskId, title: 'Draft schema', isCompleted: false),
          Subtask(id: 'sub_t_2', taskId: taskId, title: 'Implement DAOs', isCompleted: false),
        ],
      );

      await db.insertFullTask(task: task, badgeIds: ['badge_do_asap', 'badge_hard_heavy']);

      final tasks = await db.watchTasksWithDetails().first;
      final retrieved = tasks.firstWhere((t) => t.id == taskId);

      expect(retrieved.title, equals('Complete Software Architecture Plan'));
      expect(retrieved.subjectCode, equals('CS'));
      expect(retrieved.subtasks.length, equals(2));
      expect(retrieved.badges.length, equals(2));
      expect(retrieved.progress, equals(0.0));
      expect(retrieved.isAllCompleted, isFalse);
    });

    test('Bidirectional Subtask <-> TimeBlock completion sync', () async {
      final taskId = 'task_sync_test';
      final subtaskId = 'sub_sync_test';
      final blockId = 'block_sync_test';
      final now = DateTime.now();

      // 1. Insert task with subtask
      final task = TaskItem(
        id: taskId,
        title: 'Sync Architecture Task',
        subjectCode: 'ARCH',
        columnId: 'col_doing_now',
        createdAt: now,
        subtasks: [
          Subtask(id: subtaskId, taskId: taskId, title: 'Write sync tests', isCompleted: false),
        ],
      );
      await db.insertFullTask(task: task, badgeIds: []);

      // 2. Schedule a linked TimeBlock for that subtask
      final block = TimeBlock(
        id: blockId,
        taskId: taskId,
        subtaskId: subtaskId,
        title: 'Write sync tests [ARCH]',
        startTime: now,
        endTime: now.add(const Duration(minutes: 45)),
        colorHex: 0xFF10B981,
        isCompleted: false,
      );
      await db.insertTimeBlock(block);

      // Verify initial states are false
      var blocks = await db.watchTimeBlocksForDay(now).first;
      expect(blocks.firstWhere((b) => b.id == blockId).isCompleted, isFalse);

      // 3. Mark subtask completed in Board -> should automatically mark TimeBlock complete!
      await db.toggleSubtask(subtaskId, true);

      blocks = await db.watchTimeBlocksForDay(now).first;
      expect(blocks.firstWhere((b) => b.id == blockId).isCompleted, isTrue);

      // 4. Mark TimeBlock uncompleted in Timeline -> should automatically uncheck subtask!
      await db.toggleTimeBlock(blockId, false);

      final tasks = await db.watchTasksWithDetails().first;
      final updatedSub = tasks.firstWhere((t) => t.id == taskId).subtasks.firstWhere((s) => s.id == subtaskId);
      expect(updatedSub.isCompleted, isFalse);
    });

    test('Task progress computation updates dynamically', () {
      final task = TaskItem(
        id: '1',
        title: 'T',
        subjectCode: 'S',
        columnId: 'col',
        createdAt: DateTime.now(),
        subtasks: [
          Subtask(id: 's1', taskId: '1', title: '1', isCompleted: true),
          Subtask(id: 's2', taskId: '1', title: '2', isCompleted: false),
        ],
      );

      expect(task.progress, equals(0.5));
      expect(task.completedSubtasks, equals(1));
      expect(task.totalSubtasks, equals(2));
      expect(task.isAllCompleted, isFalse);
    });

    test('Task persists distinct toDoDate and dueDate', () async {
      final taskId = 'task_dates_test';
      final now = DateTime.now();
      final toDo = DateTime(now.year, now.month, now.day, 10, 0);
      final due = DateTime(now.year, now.month, now.day + 5, 17, 0);

      final task = TaskItem(
        id: taskId,
        title: 'Distinct Dates Task',
        subjectCode: 'DATES',
        columnId: 'col_doing_now',
        toDoDate: toDo,
        dueDate: due,
        createdAt: now,
      );

      await db.insertFullTask(task: task, badgeIds: []);

      final tasks = await db.watchTasksWithDetails().first;
      final retrieved = tasks.firstWhere((t) => t.id == taskId);

      expect(retrieved.toDoDate, equals(toDo));
      expect(retrieved.dueDate, equals(due));
      expect(retrieved.toDoDate, isNot(equals(retrieved.dueDate)));
    });

    test('Release ready: initial seeded database contains 0 prebuilt tasks or sample blocks', () async {
      final cleanDb = AppDatabase(openConnection(inMemory: true));
      await DatabaseSeeder.seed(cleanDb);

      final initialTasks = await cleanDb.select(cleanDb.tasks).get();
      final initialBlocks = await cleanDb.select(cleanDb.timeBlocks).get();

      expect(initialTasks.isEmpty, isTrue);
      expect(initialBlocks.isEmpty, isTrue);

      await cleanDb.close();
    });
  });
}

