import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/tempo_theme.dart';

class NowIndicator extends StatefulWidget {
  final double hourHeight;
  final bool enableTimer;

  const NowIndicator({
    super.key,
    required this.hourHeight,
    this.enableTimer = true,
  });

  @override
  State<NowIndicator> createState() => _NowIndicatorState();
}

class _NowIndicatorState extends State<NowIndicator> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.enableTimer) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() => _now = DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutesSinceMidnight = _now.hour * 60 + _now.minute;
    final topPosition = (minutesSinceMidnight / 60.0) * widget.hourHeight;

    return Positioned(
      top: topPosition - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: TempoTheme.pastelRose,
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: TempoTheme.pastelRose.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
