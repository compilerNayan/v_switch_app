import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/usage_response.dart';
import '../../core/utils/units.dart';

enum ChartDisplayMode { bar, cumulativeLine }

class UsageChart extends StatelessWidget {
  const UsageChart({
    super.key,
    required this.dataPoints,
    required this.granularity,
    required this.unit,
    required this.mode,
    this.height = 220,
    this.compactLabels = false,
  });

  final List<UsageDataPoint> dataPoints;
  final Granularity granularity;
  final VolumeUnit unit;
  final ChartDisplayMode mode;
  final double height;
  final bool compactLabels;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data for this period')),
      );
    }

    final values = mode == ChartDisplayMode.bar
        ? dataPoints
            .map((p) => VolumeFormatter.fromLiters(p.volumeLiters, unit))
            .toList()
        : _cumulativeValues(dataPoints, unit);

    final maxY = values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;

    return SizedBox(
      height: height,
      child: mode == ChartDisplayMode.bar
          ? BarChart(_barData(context, values, chartMaxY))
          : LineChart(_lineData(context, values, chartMaxY)),
    );
  }

  List<double> _cumulativeValues(List<UsageDataPoint> points, VolumeUnit unit) {
    var total = 0.0;
    return points.map((p) {
      total += VolumeFormatter.fromLiters(p.volumeLiters, unit);
      return total;
    }).toList();
  }

  BarChartData _barData(
    BuildContext context,
    List<double> values,
    double chartMaxY,
  ) {
    final color = Theme.of(context).colorScheme.primary;
    return BarChartData(
      maxY: chartMaxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: chartMaxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _titles(context, values.length),
      barGroups: List.generate(values.length, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              color: color,
              width: values.length > 48 ? 4 : 10,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        );
      }),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final point = dataPoints[group.x];
            return BarTooltipItem(
              '${VolumeFormatter.format(point.volumeLiters, unit)}\n${_formatTimestamp(point.timestamp)}',
              const TextStyle(color: Colors.white, fontSize: 12),
            );
          },
        ),
      ),
    );
  }

  LineChartData _lineData(
    BuildContext context,
    List<double> values,
    double chartMaxY,
  ) {
    final color = Theme.of(context).colorScheme.secondary;
    final spots = List.generate(
      values.length,
      (i) => FlSpot(i.toDouble(), values[i]),
    );

    return LineChartData(
      maxY: chartMaxY,
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: chartMaxY / 4,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: _titles(context, values.length),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: color,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.15),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final idx = spot.x.toInt().clamp(0, dataPoints.length - 1);
              final point = dataPoints[idx];
              return LineTooltipItem(
                '${spot.y.toStringAsFixed(1)} ${unit.symbol}\n${_formatTimestamp(point.timestamp)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  FlTitlesData _titles(BuildContext context, int count) {
    final labelInterval = _labelInterval(count);
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(0),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: labelInterval,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            if (index < 0 || index >= dataPoints.length) {
              return const SizedBox.shrink();
            }
            if (index % labelInterval.round() != 0 && count > 12) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formatAxisLabel(dataPoints[index].timestamp),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            );
          },
        ),
      ),
    );
  }

  double _labelInterval(int count) {
    if (count <= 12) return 1;
    if (count <= 24) return 2;
    if (count <= 48) return 4;
    return (count / 6).ceilToDouble();
  }

  String _formatAxisLabel(DateTime timestamp) {
    if (compactLabels) {
      return DateFormat.Hm().format(timestamp.toLocal());
    }
    switch (granularity) {
      case Granularity.d1:
        return DateFormat.MMMd().format(timestamp.toLocal());
      case Granularity.h1:
      case Granularity.m30:
      case Granularity.m15:
      case Granularity.m5:
      case Granularity.m1:
        return DateFormat.Hm().format(timestamp.toLocal());
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat.yMMMd().add_Hm().format(timestamp.toLocal());
  }
}

class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.dataPoints,
    required this.unit,
  });

  final List<UsageDataPoint> dataPoints;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) {
      return const SizedBox(height: 48);
    }

    final values = dataPoints
        .map((p) => VolumeFormatter.fromLiters(p.volumeLiters, unit))
        .toList();
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.2;
    final color = Theme.of(context).colorScheme.onPrimary;

    return SizedBox(
      height: 48,
      child: LineChart(
        LineChartData(
          maxY: chartMaxY,
          minY: 0,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                values.length,
                (i) => FlSpot(i.toDouble(), values[i]),
              ),
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
    this.height = 180,
    this.highlightLast = false,
  });

  final List<double> values;
  final List<String> labels;
  final VolumeUnit unit;
  final double height;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No data')),
      );
    }

    final maxY = values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: chartMaxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Text(
                    labels[i],
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(values.length, (i) {
            final isHighlight = highlightLast && i == values.length - 1;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: isHighlight ? secondary : primary.withValues(alpha: 0.75),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
