import 'package:flutter/material.dart';
import '../core/constants.dart';

class TimeRuler extends StatelessWidget {
  final DateTime startTime;
  final ScrollController scrollController;

  const TimeRuler({
    super.key,
    required this.startTime,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Round down to nearest hour
    final base = DateTime(
      startTime.year, startTime.month, startTime.day,
      startTime.hour, 0,
    );

    return Container(
      color: kSurfaceColor,
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          // 12 hours × 60 min × kMinuteWidth
          width: 12 * 60 * kMinuteWidth,
          child: Stack(
            children: [
              // Vertical divider lines every 30 min
              for (int i = 0; i < 24; i++)
                Positioned(
                  left: i * 30 * kMinuteWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: kBorderColor.withOpacity(i % 2 == 0 ? 0.8 : 0.3),
                  ),
                ),
              // Time labels every 30 min
              for (int i = 0; i < 24; i++)
                Positioned(
                  left: i * 30 * kMinuteWidth + 6,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatTime(base.add(Duration(minutes: i * 30))),
                      style: TextStyle(
                        color: i % 2 == 0 ? kTextSecondary : kTextDim,
                        fontSize: i % 2 == 0 ? 13 : 11,
                        fontWeight: i % 2 == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
