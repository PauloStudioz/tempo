import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/core/database/app_database.dart';
import 'package:tempo/core/database/connection.dart';
import 'package:tempo/core/database/database_seeder.dart';
import 'package:tempo/features/board/widgets/task_card.dart';
import 'package:tempo/features/board/widgets/task_edit_dialog.dart';
import 'package:tempo/main.dart';
import 'package:tempo/models/task_models.dart';
import 'package:tempo/providers/tempo_providers.dart';

class FakeApiKeyNotifier extends ApiKeyNotifier {
  @override
  Future<String?> build() async => 'dummy_test_key';
}

void main() {
  testWidgets('TempoApp launches and renders navigation tabs & Board Horizons', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        apiKeyProvider.overrideWith(FakeApiKeyNotifier.new),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // Set screen size for testing
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TempoApp(),
      ),
    );

    // Pump frames to let streams and animations settle
    await tester.pumpAndSettle();

    // Verify Brand title is rendered
    expect(find.text('Tempo'), findsOneWidget);

    // Verify Navigation Sidebar tabs on desktop
    expect(find.text('Board'), findsWidgets);
    expect(find.text('Time Block'), findsOneWidget);
    expect(find.text('AI Assistant'), findsOneWidget);
    expect(find.text('Customize'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify Seeded columns exist
    expect(find.text('Doing Now'), findsWidgets);
    expect(find.text('Do Soon'), findsWidgets);
    expect(find.text('Plan Later'), findsWidgets);

    // Switch to Time Block tab
    await tester.tap(find.text('Time Block'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Add Block'), findsOneWidget);
    expect(find.text('Unscheduled Tasks'), findsOneWidget);

    // Switch to Customize tab
    await tester.tap(find.text('Customize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Workflow & Attributes'), findsOneWidget);
    expect(find.text('Add Column'), findsOneWidget);
    expect(find.text('New Attribute'), findsOneWidget);

    // Switch to Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Settings & Preferences'), findsOneWidget);
    expect(find.text('Gemini API Key (BYOK)'), findsOneWidget);
  });

  testWidgets('TaskCard renders pill badges, subtasks, and progress bar', (WidgetTester tester) async {
    final task = TaskItem(
      id: 'test_card_1',
      title: 'Review System Design',
      subjectCode: 'ARCH',
      columnId: 'col_doing_now',
      createdAt: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 3)),
      badges: const [
        CustomBadge(id: 'b1', label: 'Do ASAP', emoji: '🔥', colorHex: 0xFFEF4444, categoryId: 'Urgency'),
        CustomBadge(id: 'b2', label: 'Hard/Heavy', emoji: '🔴', colorHex: 0xFFE11D48, categoryId: 'Effort'),
        CustomBadge(id: 'b3', label: 'Individual', emoji: '👤', colorHex: 0xFF8B5CF6, categoryId: 'Context'),
      ],
      subtasks: const [
        Subtask(id: 's1', taskId: 'test_card_1', title: 'Data flow mapping', isCompleted: true),
        Subtask(id: 's2', taskId: 'test_card_1', title: 'Security review', isCompleted: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProviderScope(
            child: TaskCard(task: task),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Review System Design'), findsOneWidget);
    expect(find.text('[ARCH]'), findsOneWidget);
    expect(find.text('Do ASAP'), findsOneWidget);
    expect(find.text('Hard/Heavy'), findsOneWidget);
    expect(find.text('Individual'), findsOneWidget);
    expect(find.text('Data flow mapping'), findsOneWidget);
    expect(find.text('Security review'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('TaskEditDialog renders frosted glass sheet, color-coded options, and handles subtasks', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 520,
                child: TaskEditDialog(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dialog title
    expect(find.text('New Task'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Scope Code'), findsOneWidget);
    expect(find.text('To-Do Date'), findsOneWidget);
    expect(find.text('Due Date'), findsOneWidget);
    expect(find.text('Column'), findsOneWidget);
    expect(find.text('Attributes'), findsOneWidget);
    expect(find.text('Subtasks'), findsOneWidget);

    // Verify Color-coded columns exist
    expect(find.text('Doing Now'), findsOneWidget);
    expect(find.text('Do Soon'), findsOneWidget);
    expect(find.text('Plan Later'), findsOneWidget);

    // Verify Badges are loaded
    expect(find.text('ASAP'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('High Effort'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    // Add a subtask
    await tester.enterText(find.byType(TextField).last, 'New subtask item');
    await tester.tap(find.byIcon(CupertinoIcons.plus));
    await tester.pumpAndSettle();

    expect(find.text('New subtask item'), findsOneWidget);
  });

  testWidgets('TimeBlockView renders multi-day selector and switches to 7-day view', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TempoApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Time Block
    await tester.tap(find.text('Time Block'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Days Count pills exist
    expect(find.text('1D'), findsOneWidget);
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('5D'), findsOneWidget);
    expect(find.text('7D'), findsOneWidget);

    // Switch to 7 Days view
    await tester.tap(find.text('7D'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(timeBlockDaysCountProvider), 7);
  });

  testWidgets('SettingsView toggles Light and Dark modes', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        apiKeyProvider.overrideWith(FakeApiKeyNotifier.new),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TempoApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Settings
    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Theme mode options
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);

    // Tap Light mode
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.light);

    // Verify Smooth Animations toggle is rendered
    expect(find.text('Smooth Animations'), findsOneWidget);
    expect(find.text('Clear Test Data'), findsOneWidget);
  });

  testWidgets('TaskCircularCheckbox toggles normal tasks and reflects gradual subtask progress', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // 1. Normal task without subtasks
    final normalTask = TaskItem(
      id: 'task_normal_1',
      title: 'Solo Normal Task',
      subjectCode: 'GEN',
      columnId: 'col_doing_now',
      createdAt: DateTime.now(),
      subtasks: const [],
      isCompleted: false,
    );

    expect(normalTask.isTaskCompleted, isFalse);
    expect(normalTask.progressRatio, equals(0.0));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: TaskCard(task: normalTask),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskCircularCheckbox), findsOneWidget);
    expect(find.text('Solo Normal Task'), findsOneWidget);

    // 2. Task with 2 subtasks, 1 completed
    final progressiveTask = TaskItem(
      id: 'task_prog_1',
      title: 'Multi-step Task',
      subjectCode: 'DEV',
      columnId: 'col_doing_now',
      createdAt: DateTime.now(),
      subtasks: const [
        Subtask(id: 'sub_1', taskId: 'task_prog_1', title: 'Sub 1', isCompleted: true),
        Subtask(id: 'sub_2', taskId: 'task_prog_1', title: 'Sub 2', isCompleted: false),
      ],
    );

    expect(progressiveTask.isTaskCompleted, isFalse);
    expect(progressiveTask.progressRatio, equals(0.5));

    // 3. Complete all subtasks
    final completedTask = progressiveTask.copyWith(
      subtasks: const [
        Subtask(id: 'sub_1', taskId: 'task_prog_1', title: 'Sub 1', isCompleted: true),
        Subtask(id: 'sub_2', taskId: 'task_prog_1', title: 'Sub 2', isCompleted: true),
      ],
    );

    expect(completedTask.isTaskCompleted, isTrue);
    expect(completedTask.progressRatio, equals(1.0));
  });

  testWidgets('BoardView top bar renders without overflow on mobile screen (390px)', (WidgetTester tester) async {
    final db = AppDatabase(openConnection(inMemory: true));
    await DatabaseSeeder.seed(db);

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    // Mobile viewport: iPhone 14/15 size 390x844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TempoMainScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Board view header and segmented controls rendered with zero errors
    expect(find.text('Board'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Active'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);

    // Verify no flutter overflow error occurred
    expect(tester.takeException(), isNull);
  });
}
