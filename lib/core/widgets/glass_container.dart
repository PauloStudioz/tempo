import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tempo_theme.dart';

class GlassContainer extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final bool enableHoverGlow;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.margin,
    this.blur = 20,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.8,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.enableHoverGlow = true,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBg = widget.backgroundColor ??
        (isDark
            ? (_isHovered
                ? TempoTheme.surfaceDark.withValues(alpha: 0.75)
                : TempoTheme.surfaceDark.withValues(alpha: 0.55))
            : (_isHovered
                ? Colors.white.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.72)));

    // Tonal elevation: No harsh outer border by default; soft hairline stroke only on hover
    final effectiveBorder = widget.borderColor ??
        (_isHovered
            ? (isDark ? TempoTheme.glassBorderFocused : TempoTheme.lightGlassBorder)
            : Colors.transparent);

    Widget content = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x1F000000) : const Color(0x0A000000),
            blurRadius: _isHovered ? 14 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: widget.padding ?? const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: effectiveBorder,
                width: widget.borderWidth,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      content = InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: content,
      );
    }

    if (widget.enableHoverGlow) {
      content = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: content,
      );
    }

    return content;
  }
}
