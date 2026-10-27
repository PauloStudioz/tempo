import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class TimeBlockDialog extends ConsumerStatefulWidget {
  final TimeBlock? initialBlock;
  final DateTime defaultDay;
  final int? defaultStartHour;

  const TimeBlockDialog({
    super.key,
    this.initialBlock,
    required this.defaultDay,
    this.defaultStartHour,
  });

  static Future<void> show(
    BuildContext context, {
    TimeBlock? initialBlock,
    required DateTime defaultDay,
    int? defaultStartHour,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: Colors.transparent,
            child: TimeBlockDialog(
              initialBlock: initialBlock,
              defaultDay: defaultDay,
              defaultStartHour: defaultStartHour,
            ),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<TimeBlockDialog> createState() => _TimeBlockDialogState();
}

class _TimeBlockDialogState extends ConsumerState<TimeBlockDialog> {
  late TextEditingController _titleController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _selectedColorHex;

  static const _pastelSwatches = [
    0xFF7DD3FC, // Pastel Sky
    0xFF6EE7B7, // Pastel Mint
    0xFFF87171, // Pastel Rose
    0xFFA78BFA, // Pastel Lilac
    0xFFFBBF24, // Pastel Honey
    0xFF94A3B8, // Pastel Slate
  ];

  @override
  void initState() {
    super.initState();
    final block = widget.initialBlock;
    _titleController = TextEditingController(text: block?.title ?? '');

    final startHour = block?.startTime.hour ?? widget.defaultStartHour ?? 10;
    final startMin = block?.startTime.minute ?? 0;
    _startTime = TimeOfDay(hour: startHour, minute: startMin);

    final endHour = block?.endTime.hour ?? (startHour + 1);
    final endMin = block?.endTime.minute ?? 0;
    _endTime = TimeOfDay(hour: endHour, minute: endMin);

    _selectedColorHex = block?.colorHex ?? _pastelSwatches.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final baseDay = widget.defaultDay;
    final start = DateTime(baseDay.year, baseDay.month, baseDay.day, _startTime.hour, _startTime.minute);
    var end = DateTime(baseDay.year, baseDay.month, baseDay.day, _endTime.hour, _endTime.minute);

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      end = start.add(const Duration(minutes: 60));
    }

    final db = ref.read(databaseProvider);

    final block = TimeBlock(
      id: widget.initialBlock?.id ?? const Uuid().v4(),
      taskId: widget.initialBlock?.taskId,
      subtaskId: widget.initialBlock?.subtaskId,
      title: title,
      startTime: start,
      endTime: end,
      colorHex: _selectedColorHex,
      isCompleted: widget.initialBlock?.isCompleted ?? false,
    );

    if (widget.initialBlock == null) {
      await db.insertTimeBlock(block);
    } else {
      await db.updateTimeBlockData(block);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      blur: 16,
      backgroundColor: isDark
          ? TempoTheme.surfaceElevated.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.98),
      borderColor: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.initialBlock == null ? 'Schedule Block' : 'Edit Block',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark, size: 16),
                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: isDark ? TempoTheme.dividerDark : TempoTheme.lightDivider, height: 1),
          const SizedBox(height: 14),

          // Title
          TextField(
            controller: _titleController,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., Focus Session: Literature Review [RSH]',
              hintStyle: TextStyle(
                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                  width: 0.7,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                  width: 0.7,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Start & End Time Selectors
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          _startTime.format(context),
                          style: TextStyle(
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'End',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          _endTime.format(context),
                          style: TextStyle(
                            color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pastel Color Swatches
          Text(
            'Color',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _pastelSwatches.map((c) {
              final isSelected = _selectedColorHex == c;
              return GestureDetector(
                onTap: () => setState(() => _selectedColorHex = c),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(c).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Color(c) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: isSelected ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Color(c)))) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
                    fontSize: 13,
                  ),
                ),
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
