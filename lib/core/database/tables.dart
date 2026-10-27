import 'package:drift/drift.dart';

@DataClassName('BoardColumnEntry')
class BoardColumns extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get emoji => text()();
  IntColumn get orderIndex => integer()();
  IntColumn get wipLimit => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskEntry')
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subjectCode => text()(); // e.g., "ENG", "SCI", "RSH"
  TextColumn get columnId => text().references(BoardColumns, #id)();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get toDoDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get orderIndex => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SubtaskEntry')
class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get estimatedMinutes => integer().nullable()();
  IntColumn get orderIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BadgeEntry')
class Badges extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get emoji => text()();
  IntColumn get colorHex => integer()();
  TextColumn get category => text()(); // "Urgency", "Effort", "Context", "Custom"

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TaskBadgeEntry')
class TaskBadges extends Table {
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get badgeId => text().references(Badges, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, badgeId};
}

@DataClassName('TimeBlockEntry')
class TimeBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable().references(Tasks, #id, onDelete: KeyAction.setNull)();
  TextColumn get subtaskId => text().nullable().references(Subtasks, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  IntColumn get colorHex => integer()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

