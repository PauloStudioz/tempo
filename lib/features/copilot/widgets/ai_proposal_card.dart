import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/pill_badge.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';
import '../services/gemini_service.dart';

class AIProposalCard extends ConsumerStatefulWidget {
  final AIProposal proposal;
  final VoidCallback onDismiss;

  const AIProposalCard({
    super.key,
    required this.proposal,
    required this.onDismiss,
  });

  @override
  ConsumerState<AIProposalCard> createState() => _AIProposalCardState();
}

class _AIProposalCardState extends ConsumerState<AIProposalCard> {
  bool _isApplied = false;

  void _applyToBoard() async {
    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    final columns = ref.read(columnsStreamProvider).value ?? [];
    final allBadges = ref.read(badgesStreamProvider).value ?? [];

    final constUuid = const Uuid();

    for (final aiTask in widget.proposal.tasks) {
      // 1. Resolve Column
      final targetCol = columns.firstWhere(
        (c) => c.title.toLowerCase().contains(aiTask.column.toLowerCase()),
        orElse: () => columns.isNotEmpty ? columns.first : const BoardColumn(id: 'col_do_soon', title: 'Do Soon', emoji: '', order: 1),
      );

      // 2. Resolve or Create Badges
      final matchedBadgeIds = <String>[];
      for (final label in aiTask.badges) {
        final existing = allBadges.cast<CustomBadge?>().firstWhere(
              (b) => b?.label.toLowerCase() == label.toLowerCase(),
              orElse: () => null,
            );
        if (existing != null) {
          matchedBadgeIds.add(existing.id);
        } else {
          // Create new badge with pastel lilac
          final newBadge = CustomBadge(
            id: constUuid.v4(),
            label: label,
            emoji: '',
            colorHex: 0xFFA78BFA,
            categoryId: 'AI',
          );
          await db.createBadge(newBadge);
          matchedBadgeIds.add(newBadge.id);
        }
      }

      // 3. Create Task & Subtasks
      final taskId = constUuid.v4();
      final subtasksList = aiTask.subtasks.asMap().entries.map((entry) {
        return Subtask(
          id: constUuid.v4(),
          taskId: taskId,
          title: entry.value,
          isCompleted: false,
          estimatedMinutes: 30,
          orderIndex: entry.key,
        );
      }).toList();

      final taskItem = TaskItem(
        id: taskId,
        title: aiTask.title,
        subjectCode: aiTask.subject.toUpperCase(),
        columnId: targetCol.id,
        dueDate: aiTask.dueDate,
        toDoDate: aiTask.toDoDate,
        createdAt: DateTime.now(),
        order: 0,
        subtasks: subtasksList,
      );

      await db.insertFullTask(task: taskItem, badgeIds: matchedBadgeIds);
    }

    // 4. Apply Time Blocks
    for (final aiBlock in widget.proposal.timeBlocks) {
      final block = TimeBlock(
        id: constUuid.v4(),
        title: aiBlock.title,
        startTime: aiBlock.startTime,
        endTime: aiBlock.endTime,
        colorHex: 0xFF7DD3FC,
        isCompleted: false,
      );
      await db.insertTimeBlock(block);
    }

    setState(() => _isApplied = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      blur: 0,
      backgroundColor: isDark
          ? TempoTheme.surfaceDark.withValues(alpha: 0.85)
          : Colors.white.withValues(alpha: 0.94),
      borderColor: _isApplied
          ? TempoTheme.pastelMint.withValues(alpha: 0.5)
          : (isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.sparkles, size: 13, color: TempoTheme.pastelSky),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isApplied ? 'Applied to Board' : 'Proposed Plan',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _isApplied
                        ? TempoTheme.pastelMint
                        : (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary),
                  ),
                ),
              ),
              if (!_isApplied)
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Icon(
                    CupertinoIcons.xmark,
                    size: 13,
                    color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider,
            height: 1,
          ),
          const SizedBox(height: 10),

          // Proposed Tasks
          if (widget.proposal.tasks.isNotEmpty) ...[
            Text(
              'Tasks (${widget.proposal.tasks.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...widget.proposal.tasks.map((t) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.05),
                    width: 0.6,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PillBadge(label: t.subject, color: TempoTheme.pastelSky, isBracketStyle: true, isCompact: true),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            ),
                          ),
                        ),
                        if (t.dueDate != null)
                          Text(
                            DateFormatter.formatMonthDay(t.dueDate),
                            style: const TextStyle(fontSize: 10.5, color: TempoTheme.pastelHoney, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    if (t.badges.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: t.badges
                            .map((b) => PillBadge(label: b, color: TempoTheme.pastelLilac, isCompact: true))
                            .toList(),
                      ),
                    ],
                    if (t.subtasks.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      ...t.subtasks.map((s) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.circle, size: 9, color: TempoTheme.pastelSky),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              );
            }),
          ],

          // Proposed Time Blocks
          if (widget.proposal.timeBlocks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Time Blocks (${widget.proposal.timeBlocks.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...widget.proposal.timeBlocks.map((b) {
              return Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: TempoTheme.pastelSky.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: TempoTheme.pastelSky.withValues(alpha: 0.2), width: 0.6),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.clock, size: 12, color: TempoTheme.pastelSky),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.title,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      DateFormatter.formatRange(b.startTime, b.endTime),
                      style: const TextStyle(fontSize: 10.5, color: TempoTheme.pastelSky, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 10),

          // Actions
          if (!_isApplied)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onDismiss,
                  child: Text(
                    'Dismiss',
                    style: TextStyle(
                      color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: _applyToBoard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TempoTheme.pastelMint,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply to Board', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            )
          else
            const Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill, size: 14, color: TempoTheme.pastelMint),
                SizedBox(width: 6),
                Text('Added to Board & Schedule', style: TextStyle(fontSize: 11.5, color: TempoTheme.pastelMint, fontWeight: FontWeight.w500)),
              ],
            ),
        ],
      ),
    );
  }
}
