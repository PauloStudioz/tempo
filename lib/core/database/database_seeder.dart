import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  static Future<void> seed(AppDatabase db) async {
    // 1. Seed Columns (Clean minimalist typography without emojis)
    final columns = [
      BoardColumnsCompanion.insert(
        id: 'col_doing_now',
        title: 'Doing Now',
        emoji: '',
        orderIndex: 0,
        wipLimit: const Value(3),
      ),
      BoardColumnsCompanion.insert(
        id: 'col_do_soon',
        title: 'Do Soon',
        emoji: '',
        orderIndex: 1,
        wipLimit: const Value(null),
      ),
      BoardColumnsCompanion.insert(
        id: 'col_plan_later',
        title: 'Plan Later',
        emoji: '',
        orderIndex: 2,
        wipLimit: const Value(null),
      ),
    ];

    for (final col in columns) {
      await db.into(db.boardColumns).insert(col, mode: InsertMode.insertOrIgnore);
    }

    // 2. Seed Badges with Apple Pastel Colors (No Emojis)
    final badges = [
      // Urgency
      BadgesCompanion.insert(
        id: 'badge_do_asap',
        label: 'ASAP',
        emoji: '',
        colorHex: 0xFFF87171, // Pastel Rose
        category: 'Urgency',
      ),
      BadgesCompanion.insert(
        id: 'badge_do_this_week',
        label: 'This Week',
        emoji: '',
        colorHex: 0xFFFBBF24, // Pastel Honey
        category: 'Urgency',
      ),
      BadgesCompanion.insert(
        id: 'badge_later',
        label: 'Later',
        emoji: '',
        colorHex: 0xFF94A3B8, // Pastel Slate
        category: 'Urgency',
      ),
      // Effort
      BadgesCompanion.insert(
        id: 'badge_hard_heavy',
        label: 'High Effort',
        emoji: '',
        colorHex: 0xFFF87171, // Pastel Rose
        category: 'Effort',
      ),
      BadgesCompanion.insert(
        id: 'badge_medium',
        label: 'Medium Effort',
        emoji: '',
        colorHex: 0xFFFBBF24, // Pastel Honey
        category: 'Effort',
      ),
      BadgesCompanion.insert(
        id: 'badge_easy',
        label: 'Light Effort',
        emoji: '',
        colorHex: 0xFF6EE7B7, // Pastel Mint
        category: 'Effort',
      ),
      // Context
      BadgesCompanion.insert(
        id: 'badge_individual',
        label: 'Individual',
        emoji: '',
        colorHex: 0xFFA78BFA, // Pastel Lilac
        category: 'Context',
      ),
      BadgesCompanion.insert(
        id: 'badge_groupings',
        label: 'Team',
        emoji: '',
        colorHex: 0xFF7DD3FC, // Pastel Sky
        category: 'Context',
      ),
    ];

    for (final b in badges) {
      await db.into(db.badges).insert(b, mode: InsertMode.insertOrIgnore);
    }
  }

  /// Removes legacy prebuilt sample tasks and sample time blocks for release.
  static Future<void> cleanSampleTasks(AppDatabase db) async {
    try {
      await (db.delete(db.timeBlocks)..where((t) => t.id.equals('block_sample_1'))).go();
      await (db.delete(db.subtasks)..where((t) => t.taskId.isIn(['task_sample_1', 'task_sample_2']))).go();
      await (db.delete(db.taskBadges)..where((t) => t.taskId.isIn(['task_sample_1', 'task_sample_2']))).go();
      await (db.delete(db.tasks)..where((t) => t.id.isIn(['task_sample_1', 'task_sample_2']))).go();
    } catch (_) {}
  }
}
