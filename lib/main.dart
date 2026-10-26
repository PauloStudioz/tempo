import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/tempo_theme.dart';
import 'core/widgets/adaptive_scaffold.dart';
import 'features/board/views/board_view.dart';
import 'features/board/widgets/task_edit_dialog.dart';
import 'features/copilot/views/copilot_view.dart';
import 'features/customizer/views/customizer_view.dart';
import 'features/settings/views/settings_view.dart';
import 'features/timeblock/views/timeblock_view.dart';
import 'providers/tempo_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TempoApp()));
}

class TempoApp extends ConsumerWidget {
  const TempoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'TEMPO',
      debugShowCheckedModeBanner: false,
      theme: TempoTheme.lightTheme,
      darkTheme: TempoTheme.darkTheme,
      themeMode: themeMode,
      home: const TempoMainScreen(),
    );
  }
}

class TempoMainScreen extends ConsumerStatefulWidget {
  const TempoMainScreen({super.key});

  @override
  ConsumerState<TempoMainScreen> createState() => _TempoMainScreenState();
}

class _TempoMainScreenState extends ConsumerState<TempoMainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeId = ref.watch(themePresetProvider);

    final pages = [
      const BoardView(),
      const TimeBlockView(),
      CopilotView(onOpenSettings: () {
        setState(() => _selectedIndex = 4);
      }),
      const CustomizerView(),
      const SettingsView(),
    ];

    return AdaptiveScaffold(
      selectedIndex: _selectedIndex,
      onIndexChanged: (idx) {
        setState(() => _selectedIndex = idx);
      },
      onQuickAddTask: () {
        TaskEditDialog.show(context);
      },
      backgroundThemeId: themeId,
      pages: pages,
    );
  }
}
