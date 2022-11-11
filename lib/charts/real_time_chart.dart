import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

enum ChartType {
  temp,
  heart,
  step,
}

class RealTimeChart extends StatefulWidget {
  final Stream<double> dataStream;
  final ChartType chartType;

  const RealTimeChart({
    required this.dataStream,
    required this.chartType,
    super.key,
  });

  @override
  State<RealTimeChart> createState() => _RealTimeChartState();
}

class _RealTimeChartState extends State<RealTimeChart> {
  late Color lineColor;

  late double minY;
  late double maxY;

  final points = <FlSpot>[];
  double xCount = 0;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    switch (widget.chartType) {
      case ChartType.temp:
        lineColor = Colors.blueAccent;
        minY = 35.5;
        maxY = 37.5;

        break;
      case ChartType.heart:
        lineColor = Colors.redAccent;
        minY = 40.0;
        maxY = 140.0;
        break;
      case ChartType.step:
        lineColor = Colors.green;
        minY = 0;
        maxY = 20000;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.dataStream,
      builder: (context, snapshot) {
        if (snapshot.data != null && snapshot.data! > 0) {
          xCount = xCount + 0.05;
          points.add(FlSpot(xCount.toDouble(), snapshot.data!));
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.chartType.toString().split(".").last.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 30,
                  ),
                ),
                Text(
                  "DATA : ${snapshot.data}",
                  style: TextStyle(
                    fontSize: 21,
                    color: lineColor,
                  ),
                ),
              ],
            ),
            Expanded(
              child: LineChart(
                _chartData(),
              ),
            ),
          ],
        );
      },
    );
  }

  LineChartData _chartData() {
    _convertY();

    return LineChartData(
      minY: minY,
      maxY: maxY,
      minX: 0.0,
      maxX: points.isEmpty ? 0.0 : points.last.x + 1.0,
      lineTouchData: LineTouchData(enabled: true),
      gridData: FlGridData(
        show: true,
      ),
      lineBarsData: _buildLine(),
      titlesData: FlTitlesData(
        show: false,
      ),
    );
  }

  List<LineChartBarData> _buildLine() {
    final results = <LineChartBarData>[];

    results.add(
      LineChartBarData(
        spots: points,
        dotData: FlDotData(
          show: false,
        ),
        color: lineColor,
        barWidth: 2,
        isCurved: true,
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lineColor.withOpacity(0.1), lineColor.withOpacity(0.1)],
          ),
        ),
      ),
    );

    return results;
  }

  Map<String, double> _minMaxFind(double max, double min, List<double> data) {
    for (var element in data) {
      max = math.max(max, element);
      min = math.min(min, element);
    }

    return {'max': max, 'min': min};
  }

  void _convertY() {
    if (widget.chartType == ChartType.step) {
      final resultY = _minMaxFind(0, 0, [for (var e in points) e.y]);
      minY = resultY["min"]!;
      maxY = resultY["max"]! + 10.0;
    }
  }
}
