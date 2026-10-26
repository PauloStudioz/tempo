import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class ColumnManagerSheet extends ConsumerStatefulWidget {
  final BoardColumn? initialColumn;

  const ColumnManagerSheet({super.key, this.initialColumn});

  static Future<void> show(BuildContext context, {BoardColumn? initialColumn}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: ColumnManagerSheet(initialColumn: initialColumn),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<ColumnManagerSheet> createState() => _ColumnManagerSheetState();
}

class _ColumnManagerSheetState extends ConsumerState<ColumnManagerSheet> {
  late TextEditingController _titleController;
  late TextEditingController _wipLimitController;

  @override
  void initState() {
    super.initState();
    final col = widget.initialColumn;
    _titleController = TextEditingController(text: col?.title ?? '');
    _wipLimitController = TextEditingController(
      text: col?.wipLimit != null ? col!.wipLimit.toString() : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _wipLimitController.dispose();
    super.dispose();
  }

  void _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final wipText = _wipLimitController.text.trim();
    final int? wipLimit = int.tryParse(wipText);

    final db = ref.read(databaseProvider);
    final columns = ref.read(columnsStreamProvider).value ?? [];

    final col = BoardColumn(
      id: widget.initialColumn?.id ?? const Uuid().v4(),
      title: title,
      emoji: '', // Emojis removed
      order: widget.initialColumn?.order ?? columns.length,
      wipLimit: (wipLimit != null && wipLimit > 0) ? wipLimit : null,
    );

    if (widget.initialColumn == null) {
      await db.createColumn(col);
    } else {
      await db.updateColumnData(col);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      backgroundColor: TempoTheme.surfaceElevated.withValues(alpha: 0.96),
      borderColor: TempoTheme.glassBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.initialColumn == null ? 'New Column' : 'Edit Column',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TempoTheme.textPrimary, letterSpacing: -0.2),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark, size: 16),
                color: TempoTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: TempoTheme.dividerDark, height: 1),
          const SizedBox(height: 14),

          // Title
          const Text('Column Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: TempoTheme.textSecondary)),
          const SizedBox(height: 5),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontSize: 13.5, color: TempoTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g., In Review, Blocked',
              hintStyle: const TextStyle(color: TempoTheme.textMuted, fontSize: 12.5),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TempoTheme.glassBorder, width: 0.6)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TempoTheme.glassBorder, width: 0.6)),
            ),
          ),
          const SizedBox(height: 14),

          // WIP Limit
          const Text('Work In Progress (WIP) Limit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: TempoTheme.textSecondary)),
          const SizedBox(height: 5),
          TextField(
            controller: _wipLimitController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, color: TempoTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Optional limit (e.g., 3). Leave blank for unlimited.',
              hintStyle: const TextStyle(color: TempoTheme.textMuted, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TempoTheme.glassBorder, width: 0.6)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TempoTheme.glassBorder, width: 0.6)),
            ),
          ),
          const SizedBox(height: 18),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: TempoTheme.textSecondary, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TempoTheme.pastelSky,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
