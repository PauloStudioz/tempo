import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/tempo_theme.dart';

class TypingIndicatorBubble extends StatefulWidget {
  final Color accentColor;

  const TypingIndicatorBubble({
    super.key,
    required this.accentColor,
  });

  @override
  State<TypingIndicatorBubble> createState() => _TypingIndicatorBubbleState();
}

class _TypingIndicatorBubbleState extends State<TypingIndicatorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0, isDark),
                const SizedBox(width: 5),
                _buildDot(1, isDark),
                const SizedBox(width: 5),
                _buildDot(2, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDot(int index, bool isDark) {
    // Stagger phase for each dot
    final phase = index * 0.22;
    final t = (_controller.value - phase) % 1.0;
    // Parabolic bounce jump up and down
    final jump = (t < 0.45) ? math.sin(t / 0.45 * math.pi) * 6.5 : 0.0;

    return Transform.translate(
      offset: Offset(0, -jump),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: (jump > 1.5)
              ? widget.accentColor
              : (isDark ? TempoTheme.textSecondary : TempoTheme.lightTextSecondary),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

