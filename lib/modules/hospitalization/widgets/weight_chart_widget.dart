import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';

/// Feature 15: Weight Trend Chart
/// Displays weight data over time from vital sign logs.
class WeightChartWidget extends StatelessWidget {
  /// List of {date: String, weight: double} maps
  final List<Map<String, dynamic>> weightData;

  const WeightChartWidget({super.key, required this.weightData});

  @override
  Widget build(BuildContext context) {
    if (weightData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'Chưa có dữ liệu cân nặng',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
          ],
        ),
      );
    }

    // Build spots from data
    final spots = <FlSpot>[];
    final dates = <String>[];
    for (int i = 0; i < weightData.length; i++) {
      spots.add(FlSpot(i.toDouble(), weightData[i]['weight'] as double));
      dates.add(weightData[i]['date'] as String);
    }

    // Calculate Y axis range
    final weights = spots.map((s) => s.y).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final yPadding = (maxW - minW) * 0.2;
    final yMin = (minW - yPadding).clamp(0.0, double.infinity);
    final yMax = maxW + yPadding;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Row(
            children: [
              Icon(Icons.monitor_weight, size: 18, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Biểu Đồ Cân Nặng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: yMin,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((yMax - yMin) / 4).clamp(
                    0.1,
                    double.infinity,
                  ),
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade900,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dates.length)
                          return const SizedBox();
                        // Show date as dd/MM
                        final parts = dates[idx].split('-');
                        final label = parts.length >= 3
                            ? '${parts[2]}/${parts[1]}'
                            : dates[idx];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = idx >= 0 && idx < dates.length
                            ? dates[idx]
                            : '';
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} kg\n$date',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),

          // Summary
          if (weightData.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_buildTrendBadge()],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendBadge() {
    final first = weightData.first['weight'] as double;
    final last = weightData.last['weight'] as double;
    final diff = last - first;
    final isGain = diff > 0;
    final isStable = diff.abs() < 0.1;

    if (isStable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.horizontal_rule, size: 16, color: Colors.blue.shade700),
            const SizedBox(width: 4),
            Text(
              'Ổn định',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isGain ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGain ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: isGain ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '${isGain ? "+" : ""}${diff.toStringAsFixed(1)} kg',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isGain ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
