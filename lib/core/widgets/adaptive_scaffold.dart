import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tempo_providers.dart';
import '../theme/tempo_theme.dart';
import '../utils/date_formatter.dart';
import 'glass_container.dart';

class AdaptiveScaffold extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final List<Widget> pages;
  final VoidCallback? onQuickAddTask;
  final String backgroundThemeId;

  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.pages,
    this.onQuickAddTask,
    this.backgroundThemeId = 'obsidian',
  });

  @override
  ConsumerState<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends ConsumerState<AdaptiveScaffold> {
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isControlOrMeta = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      if (isControlOrMeta) {
        if (event.logicalKey == LogicalKeyboardKey.keyN) {
          widget.onQuickAddTask?.call();
        } else if (event.logicalKey == LogicalKeyboardKey.digit1) {
          widget.onIndexChanged(0);
        } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
          widget.onIndexChanged(1);
        } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
          widget.onIndexChanged(2);
        } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
          widget.onIndexChanged(3);
        } else if (event.logicalKey == LogicalKeyboardKey.digit5) {
          widget.onIndexChanged(4);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customBg = ref.watch(customBackgroundProvider);
    final accentColor = ref.watch(customAccentColorProvider);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: customBg.backgroundColor,
        body: Stack(
          children: [
            // 1. Atmosphere Background Wallpaper (Custom Image or Custom Hex Color)
            Positioned.fill(
              child: customBg.imageBytes != null
                  ? Image.memory(
                      customBg.imageBytes!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  customBg.backgroundColor,
                                  customBg.backgroundColor.withValues(alpha: 0.85),
                                  Color.alphaBlend(accentColor.withValues(alpha: 0.08), customBg.backgroundColor),
                                ]
                              : [
                                  const Color(0xFFFBFBFC),
                                  const Color(0xFFF2F2F7),
                                  const Color(0xFFE5E5EA),
                                ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
            ),

            // Subtle scrim overlay
            Positioned.fill(
              child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: customBg.imageBytes != null ? 0.35 : 0.0)
                    : Colors.white.withValues(alpha: customBg.imageBytes != null ? 0.25 : 0.0),
              ),
            ),

            // Gaussian blur layer over background
            if (customBg.blurSigma > 0)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: customBg.blurSigma, sigmaY: customBg.blurSigma),
                  child: const SizedBox.expand(),
                ),
              ),

            // 2. Main Content
            SafeArea(
              child: isDesktop
                  ? _buildDesktopLayout(context, isDark, accentColor, customBg)
                  : _buildMobileLayout(context, isDark, accentColor, customBg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isDark, Color accentColor, CustomBackgroundState customBg) {
    final columns = ref.watch(columnsStreamProvider).value ?? [];
    final tasks = ref.watch(tasksStreamProvider).value ?? [];
    final timeBlocks = ref.watch(timeBlocksStreamProvider).value ?? [];

    // Calculate today's stats
    final totalTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.isAllCompleted).length;
    final taskProgress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    // Find current active time block or next upcoming
    final now = DateTime.now();
    final currentBlock = timeBlocks.where((b) => b.startTime.isBefore(now) && b.endTime.isAfter(now)).firstOrNull;
    final nextBlock = timeBlocks.where((b) => b.startTime.isAfter(now)).firstOrNull;

    return Row(
      children: [
        // Refined Minimalist macOS Sidebar (Rich executive dashboard, no empty void)
        Container(
          width: 230,
          margin: const EdgeInsets.fromLTRB(14, 12, 0, 12),
          child: GlassContainer(
            borderRadius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            backgroundColor: isDark
                ? TempoTheme.surfaceDark.withValues(alpha: customBg.surfaceTranslucency)
                : Colors.white.withValues(alpha: (customBg.surfaceTranslucency * 0.90).clamp(0.15, 0.92)),
            borderColor: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean typographic header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Tempo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // macOS Style New Task Pill
                if (widget.onQuickAddTask != null)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onQuickAddTask?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.plus,
                              color: accentColor,
                              size: 13,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'New Task',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '⌘N',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                Divider(
                  color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
                  height: 1,
                ),
                const SizedBox(height: 10),

                // Main Navigation Items
                _buildSidebarItem(
                  index: 0,
                  icon: CupertinoIcons.square_grid_2x2,
                  activeIcon: CupertinoIcons.square_grid_2x2_fill,
                  label: 'Board',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 3),
                _buildSidebarItem(
                  index: 1,
                  icon: CupertinoIcons.clock,
                  activeIcon: CupertinoIcons.clock_fill,
                  label: 'Time Block',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 3),
                _buildSidebarItem(
                  index: 2,
                  icon: CupertinoIcons.sparkles,
                  activeIcon: CupertinoIcons.sparkles,
                  label: 'AI Assistant',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 3),
                _buildSidebarItem(
                  index: 3,
                  icon: CupertinoIcons.slider_horizontal_3,
                  activeIcon: CupertinoIcons.slider_horizontal_3,
                  label: 'Customize',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 3),
                _buildSidebarItem(
                  index: 4,
                  icon: CupertinoIcons.gear,
                  activeIcon: CupertinoIcons.gear_solid,
                  label: 'Settings',
                  isDark: isDark,
                  accentColor: accentColor,
                ),

                const SizedBox(height: 14),
                Divider(
                  color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
                  height: 1,
                ),
                const SizedBox(height: 12),

                // ==========================================
                // SIDEBAR HORIZONS SUMMARY (Eliminates empty void)
                // ==========================================
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    'HORIZONS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...columns.map((col) {
                  final colTasksCount = tasks.where((t) => t.columnId == col.id && !t.isAllCompleted).length;
                  final lower = col.title.toLowerCase();
                  final dotColor = lower.contains('now')
                      ? TempoTheme.pastelRose
                      : (lower.contains('soon') ? TempoTheme.pastelHoney : TempoTheme.pastelLilac);

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onIndexChanged(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                col.title,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$colTasksCount',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const Spacer(),

                // ==========================================
                // TODAY'S FOCUS & SCHEDULE WIDGET
                // ==========================================
                if (currentBlock != null || nextBlock != null) ...[
                  GestureDetector(
                    onTap: () => widget.onIndexChanged(1),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: currentBlock != null ? TempoTheme.pastelMint : accentColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  currentBlock != null ? 'NOW' : 'UP NEXT',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: currentBlock != null ? TempoTheme.pastelMint : accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormatter.formatTime(currentBlock?.startTime ?? nextBlock!.startTime),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currentBlock?.title ?? nextBlock!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Momentum Mini Gauge
                Container(
                  padding: const EdgeInsets.all(9),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'MOMENTUM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$completedTasks/$totalTasks done',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: taskProgress,
                          minHeight: 3,
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                    ],
                  ),
                ),

                // Subtle macOS Keyboard Shortcut Hint
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '⌘1–5 to switch',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? TempoTheme.textMuted.withValues(alpha: 0.7)
                          : TempoTheme.lightTextMuted.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Active View Container with Fluid Apple Transition
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.01, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(widget.selectedIndex),
                child: widget.pages[widget.selectedIndex],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    required Color accentColor,
  }) {
    final isSelected = widget.selectedIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onIndexChanged(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected
                    ? accentColor
                    : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                size: 15,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.1,
                    color: isSelected
                        ? (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary)
                        : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isDark, Color accentColor, CustomBackgroundState customBg) {
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: widget.pages[widget.selectedIndex],
          ),
        ),

        // Translucent Cupertino Bottom Navigation Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: GlassContainer(
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            backgroundColor: isDark
                ? TempoTheme.surfaceDark.withValues(alpha: customBg.surfaceTranslucency)
                : Colors.white.withValues(alpha: (customBg.surfaceTranslucency * 0.90).clamp(0.15, 0.92)),
            borderColor: Colors.transparent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavItem(
                  index: 0,
                  icon: CupertinoIcons.square_grid_2x2,
                  activeIcon: CupertinoIcons.square_grid_2x2_fill,
                  label: 'Board',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildBottomNavItem(
                  index: 1,
                  icon: CupertinoIcons.clock,
                  activeIcon: CupertinoIcons.clock_fill,
                  label: 'Time Block',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildBottomNavItem(
                  index: 2,
                  icon: CupertinoIcons.sparkles,
                  activeIcon: CupertinoIcons.sparkles,
                  label: 'AI Assistant',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildBottomNavItem(
                  index: 3,
                  icon: CupertinoIcons.slider_horizontal_3,
                  activeIcon: CupertinoIcons.slider_horizontal_3,
                  label: 'Customize',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
                _buildBottomNavItem(
                  index: 4,
                  icon: CupertinoIcons.gear,
                  activeIcon: CupertinoIcons.gear_solid,
                  label: 'Settings',
                  isDark: isDark,
                  accentColor: accentColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isDark,
    required Color accentColor,
  }) {
    final isSelected = widget.selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onIndexChanged(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected
                  ? accentColor
                  : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary)
                    : (isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
