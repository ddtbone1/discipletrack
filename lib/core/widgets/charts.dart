import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_pill.dart';

/// One part of a [DonutChart]: how many, in which colour, called what.
typedef ChartSlice = ({int value, Color color, String label});

/// A ring split by value, with a figure in the middle and the legend beside
/// it. Drawn here, with no chart library (no dependency without need).
class DonutChart extends StatelessWidget {
  const DonutChart({
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.size = 112,
    super.key,
  });

  final List<ChartSlice> slices;
  final String centerValue;
  final String centerLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final shown = [
      for (final s in slices)
        if (s.value > 0) s,
    ];
    return Semantics(
      label: [
        '$centerValue $centerLabel',
        for (final s in shown) '${s.value} ${s.label}',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _DonutPainter(
                slices: shown,
                track: neutralFill(context),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerValue,
                      style: AppTypography.metricSmall.copyWith(
                        color: p.textPrimary,
                        height: 1,
                      ),
                    ),
                    Text(
                      centerLabel,
                      style: text.labelSmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.label,
                            style: text.bodySmall?.copyWith(color: p.muted),
                          ),
                        ),
                        Text(
                          '${s.value}',
                          style: text.bodyMedium?.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.track});

  final List<ChartSlice> slices;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final total = slices.fold<int>(0, (t, s) => t + s.value);
    if (total == 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
      return;
    }
    // A small gap between slices, drawn as round ends.
    const gap = 0.16;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = math.pi * 2 * s.value / total;
      final drawn = slices.length == 1 ? sweep : math.max(sweep - gap, 0.01);
      canvas.drawArc(
        rect,
        start + (slices.length == 1 ? 0 : gap / 2),
        drawn,
        false,
        paint..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.track != track;
}
