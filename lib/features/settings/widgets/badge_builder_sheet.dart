import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/tempo_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../models/task_models.dart';
import '../../../providers/tempo_providers.dart';

class BadgeBuilderSheet extends ConsumerStatefulWidget {
  final CustomBadge? initialBadge;

  const BadgeBuilderSheet({super.key, this.initialBadge});

  static Future<void> show(BuildContext context, {CustomBadge? initialBadge}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: BadgeBuilderSheet(initialBadge: initialBadge),
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<BadgeBuilderSheet> createState() => _BadgeBuilderSheetState();
}

class _BadgeBuilderSheetState extends ConsumerState<BadgeBuilderSheet> {
  late TextEditingController _labelController;
  late int _selectedColorHex;
  late String _selectedCategory;

  static const _pastelColors = [
    0xFF7DD3FC, // Pastel Sky
    0xFF6EE7B7, // Pastel Mint
    0xFFF87171, // Pastel Rose
    0xFFA78BFA, // Pastel Lilac
    0xFFFBBF24, // Pastel Honey
    0xFF94A3B8, // Pastel Slate
    0xFF818CF8, // Pastel Indigo
  ];

  static const _categories = ['Urgency', 'Effort', 'Context', 'Custom'];

  @override
  void initState() {
    super.initState();
    final badge = widget.initialBadge;
    _labelController = TextEditingController(text: badge?.label ?? '');
    _selectedColorHex = badge?.colorHex ?? _pastelColors.first;
    _selectedCategory = badge?.categoryId ?? 'Urgency';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _save() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;

    final db = ref.read(databaseProvider);

    final badge = CustomBadge(
      id: widget.initialBadge?.id ?? const Uuid().v4(),
      label: label,
      emoji: '', // Emojis removed per user request
      colorHex: _selectedColorHex,
      categoryId: _selectedCategory,
    );

    if (widget.initialBadge == null) {
      await db.createBadge(badge);
    } else {
      await db.updateBadgeData(badge);
    }

    if (mounted) Navigator.of(context).pop();
  }

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
                widget.initialBadge == null ? 'New Attribute' : 'Edit Attribute',
                style: TextStyle(
                  fontSize: 15,
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

          // Label
          Text(
            'Name',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: _labelController,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., High Priority, Deep Focus',
              hintStyle: TextStyle(
                color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                fontSize: 12.5,
              ),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                  width: 0.6,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder,
                  width: 0.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category Selector
          Text(
            'Category',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (val) {
                  if (val) setState(() => _selectedCategory = cat);
                },
                selectedColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                side: BorderSide(
                  color: isSelected
                      ? (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.20))
                      : (isDark ? TempoTheme.glassBorder : TempoTheme.lightGlassBorder),
                  width: 0.6,
                ),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? (isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary)
                      : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Pastel Color Swatches
          Text(
            'Pastel Color',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _pastelColors.map((c) {
              final isSelected = _selectedColorHex == c;
              return GestureDetector(
                onTap: () => setState(() => _selectedColorHex = c),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(c).withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? Color(c) : Colors.transparent, width: 2),
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
