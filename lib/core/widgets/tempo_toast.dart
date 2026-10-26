import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/tempo_theme.dart';

class TempoToast {
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.zero,
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xF01E1F24)
                  : Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon ??
                      (isError
                          ? CupertinoIcons.exclamationmark_circle_fill
                          : CupertinoIcons.checkmark_circle_fill),
                  size: 14,
                  color: isError ? TempoTheme.pastelRose : TempoTheme.pastelMint,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? TempoTheme.textPrimary : TempoTheme.lightTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => messenger.hideCurrentSnackBar(),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 9.5,
                        color: isDark ? TempoTheme.textMuted : TempoTheme.lightTextMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

