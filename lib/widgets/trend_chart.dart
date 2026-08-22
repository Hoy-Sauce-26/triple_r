import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One point on a [TrendChart].
class TrendPoint {
  const TrendPoint({required this.date, required this.value});
  final DateTime date;
  final double value;
}

/// A small line chart over time.
///
/// Shared by body weight and exercise progress because they want identical
/// treatment: sparse points, a date axis, and a y-range that does not start at
/// zero — an 82 kg body weight plotted from zero is a flat line at the top of
/// the frame, which hides exactly the variation the user opened the chart to
/// see.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.formatValue,
    this.axisLabel,
    this.height = 200,
  });

  final List<TrendPoint> points;
  final String Function(double) formatValue;

  /// What the vertical axis measures — "Best set (reps)", "Working weight".
  ///
  /// Rendered rotated against the axis rather than as a caption above the
  /// card, which is where it used to live: a line of prose over a chart reads
  /// as a heading for the whole card, so the numbers down the side stayed
  /// unlabelled and the card gained a row of text it did not need.
  final String? axisLabel;

  final double height;

  /// How many labelled gridlines the vertical axis gets.
  ///
  /// Four: enough to read a value off the middle of the line, few enough that
  /// a 200px chart does not stack them on top of each other. The old axis
  /// labelled only its two extremes, which are exactly the two values a
  /// reader can already infer from the shape.
  static const _yDivisions = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            points.isEmpty
                ? 'Nothing logged yet.'
                : 'One entry so far — a trend needs two.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }

    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final first = sorted.first.date;

    double x(DateTime d) => d.difference(first).inMinutes.toDouble();

    final values = sorted.map((p) => p.value);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    // A flat series has zero span, which fl_chart cannot scale; give it one.
    final span = (maxValue - minValue).abs() < 0.01 ? 1.0 : maxValue - minValue;
    final padding = span * 0.15;
    final minY = minValue - padding;
    final maxY = maxValue + padding;
    final yInterval = (maxY - minY) / _yDivisions;

    final lastX = x(sorted.last.date);
    // Several points logged inside the same minute collapse the horizontal
    // span to zero, which fl_chart cannot scale any better than a flat series.
    final padX = (lastX == 0 ? 1.0 : lastX) * 0.02;
    // At most four date labels, and never more than there are points — three
    // sessions across a 200px chart produced dates crammed against each other
    // at both ends.
    final xLabels = sorted.length < 4 ? sorted.length : 4;
    final xInterval = (lastX / (xLabels - 1)).clamp(1.0, double.infinity);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          // A sliver of room at each end so the first and last date labels
          // are not half-drawn against the frame.
          minX: -padX,
          maxX: lastX + padX,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colors.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              axisNameSize: axisLabel == null ? 0 : 18,
              axisNameWidget: axisLabel == null
                  ? null
                  : Text(
                      axisLabel!,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: yInterval,
                // The padded extremes are not data, and labelling them puts a
                // number hard against the frame a hair from the first real
                // gridline. The four interval marks are the scale.
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      formatValue(value),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: xInterval,
                // Same as the vertical axis: the padding either side carries
                // no session, and labelling it crammed a date against each
                // edge next to the one beside it.
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) {
                  final date = first.add(Duration(minutes: value.round()));
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${date.day}/${date.month}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colors.inverseSurface,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    formatValue(spot.y),
                    TextStyle(
                      color: colors.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final p in sorted) FlSpot(x(p.date), p.value)],
              isCurved: false,
              color: colors.primary,
              barWidth: 2,
              dotData: FlDotData(
                show: sorted.length <= 30,
                getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                  radius: 3,
                  color: colors.primary,
                  strokeWidth: 0,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: colors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
