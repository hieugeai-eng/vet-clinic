import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../data/models/hospitalization_models.dart';

class VitalSignChart extends StatelessWidget {
  final List<VitalSignLogModel> logs;
  final bool isTemperature; // true for Temp, false for Weight

  const VitalSignChart({
    super.key,
    required this.logs,
    this.isTemperature = true,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu'));
    }

    // Filter logs that have the relevant value
    final relevantLogs = logs
        .where((l) => isTemperature ? l.temperature != null : l.weight != null)
        .toList();

    // Sort by time
    relevantLogs.sort((a, b) => a.time.compareTo(b.time));

    if (relevantLogs.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu'));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < relevantLogs.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      relevantLogs[index].time,
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.black12),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: relevantLogs.asMap().entries.map((e) {
              final val = isTemperature
                  ? e.value.temperature!
                  : e.value.weight!;
              return FlSpot(e.key.toDouble(), val);
            }).toList(),
            isCurved: true,
            color: isTemperature ? Colors.red : Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}
