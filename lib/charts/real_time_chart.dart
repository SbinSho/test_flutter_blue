import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_test/models/B7Pro.dart';

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
        maxY = 200;
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: widget.dataStream,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blueAccent),
          );
        } else {
          if (snapshot.data! > 0) {
            xCount = xCount + 0.05;
            if (widget.chartType == ChartType.heart ||
                widget.chartType == ChartType.step) {}
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
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    minX: 0.0,
                    maxX: points.isEmpty ? 0.0 : points.last.x,
                    lineTouchData: LineTouchData(enabled: true),
                    gridData: FlGridData(
                      show: false,
                      drawVerticalLine: false,
                    ),
                    lineBarsData: [
                      tempLine(points),
                    ],
                    titlesData: FlTitlesData(
                      show: false,
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  LineChartBarData tempLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: FlDotData(
        show: false,
      ),
      color: lineColor,
      barWidth: 2,
      isCurved: false,
    );
  }
}
