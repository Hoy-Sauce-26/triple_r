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
    this.height = 200,
  });

  final List<TrendPoint> points;
  final String Function(double) formatValue;
  final double height;

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

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minValue - padding,
          maxY: maxValue + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
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
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  // Only the ends and the middle; a crowded axis on a 200px
                  // chart is unreadable.
                  if (value != meta.min && value != meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      formatValue(value),
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
                interval: (x(sorted.last.date) / 2).clamp(1, double.infinity),
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
