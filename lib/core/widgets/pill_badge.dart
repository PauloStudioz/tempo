import 'package:flutter/material.dart';
import '../theme/tempo_theme.dart';

class PillBadge extends StatelessWidget {
  final String label;
  final String? emoji; // Ignored for Apple HIG
  final Color color;
  final bool isBracketStyle;
  final bool isCompact;
  final bool showDot;
  final bool useNeutralStyle;
  final VoidCallback? onRemove;

  const PillBadge({
    super.key,
    required this.label,
    this.emoji,
    this.color = TempoTheme.pastelSky,
    this.isBracketStyle = false,
    this.isCompact = false,
    this.showDot = false,
    this.useNeutralStyle = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayText = isBracketStyle ? '[$label]' : label;

    final bgColor = useNeutralStyle
        ? (isDark ? TempoTheme.neutralTagDark : TempoTheme.neutralTagLight)
        : color.withValues(alpha: 0.12);

    final textColor = useNeutralStyle
        ? (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary)
        : color;

    final borderColor = useNeutralStyle
        ? Colors.transparent
        : color.withValues(alpha: 0.20);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 9,
        vertical: isCompact ? 2.5 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ],
          Text(
            displayText,
            style: TextStyle(
              fontSize: isCompact ? 10.5 : 11.5,
              fontWeight: FontWeight.w500,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 11,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
