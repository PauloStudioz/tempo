import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../providers/tempo_providers.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../settings/widgets/badge_builder_sheet.dart';
import '../../settings/widgets/column_manager_sheet.dart';

class CustomizerView extends ConsumerWidget {
  const CustomizerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columnsAsync = ref.watch(columnsStreamProvider);
    final badgesAsync = ref.watch(badgesStreamProvider);
    final accentColor = ref.watch(customAccentColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Workflow & Attributes',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customize your Kanban board columns, WIP limits, and contextual attribute badges.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 1. BOARD HORIZONS & COLUMNS
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Board Horizons & Columns',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure Kanban columns and Work-In-Progress (WIP) capacity.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => ColumnManagerSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'Add Column',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              columnsAsync.when(
                data: (cols) {
                  return GlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: isDark
                        ? TempoTheme.surfaceElevated.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.90),
                    borderColor: Colors.transparent,
                    child: Column(
                      children: cols.map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                c.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                                ),
                              ),
                              if (c.wipLimit != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'WIP: ${c.wipLimit}',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              IconButton(
                                icon: const Icon(CupertinoIcons.pencil, size: 14),
                                color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                onPressed: () => ColumnManagerSheet.show(context, initialColumn: c),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),

              // ==========================================
              // 2. CUSTOM ATTRIBUTES & BADGES
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Custom Attributes & Badges',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Create reusable context, priority, and effort tags for your tasks.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => BadgeBuilderSheet.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.plus, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            'New Attribute',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              badgesAsync.when(
                data: (badges) {
                  return GlassContainer(
                    borderRadius: 16,
                    padding: const EdgeInsets.all(12),
                    backgroundColor: isDark
                        ? TempoTheme.surfaceElevated.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.90),
                    borderColor: Colors.transparent,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: badges.map((badge) {
                        return GestureDetector(
                          onTap: () => BadgeBuilderSheet.show(context, initialBadge: badge),
                          child: PillBadge(
                            label: badge.label,
                            color: badge.color,
                            showDot: true,
                            onRemove: () async {
                              final db = ref.read(databaseProvider);
                              await db.deleteBadgeById(badge.id);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

