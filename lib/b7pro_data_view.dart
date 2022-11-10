import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'charts/real_time_chart.dart';
import 'models/B7Pro.dart';

class B7ProDataView extends StatefulWidget {
  final B7ProCommModel commModel;
  const B7ProDataView({required this.commModel, super.key});

  @override
  State<B7ProDataView> createState() => _B7ProDataViewState();
}

class _B7ProDataViewState extends State<B7ProDataView> {
  @override
  void dispose() {
    super.dispose();
    widget.commModel.disConnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.commModel.device.name),
        actions: [
          StreamBuilder<DeviceConnectionState>(
            stream: widget.commModel.connectState,
            builder: (context, snapshot) {
              Function()? onPressed;

              if (snapshot.data != null &&
                  snapshot.data! == DeviceConnectionState.connected) {
                onPressed = widget.commModel.startTask;
              }

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                ),
                onPressed: onPressed,
                child: const Text("Request"),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DeviceConnectionState>(
        stream: widget.commModel.connectState,
        initialData: DeviceConnectionState.disconnected,
        builder: (context, snapshot) {
          switch (snapshot.data!) {
            case DeviceConnectionState.connecting:
              return _buildIng(
                snapshot.data.toString().split(".").last.toString(),
              );
            case DeviceConnectionState.connected:
              return Container(
                margin: const EdgeInsetsDirectional.all(10.0),
                child: Column(
                  children: [
                    Expanded(
                      child: RealTimeChart(
                        chartType: ChartType.temp,
                        dataStream: widget.commModel.tempStream,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: RealTimeChart(
                        chartType: ChartType.heart,
                        dataStream: widget.commModel.heartStream,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: RealTimeChart(
                        chartType: ChartType.step,
                        dataStream: widget.commModel.stepStream,
                      ),
                    ),
                  ],
                ),
              );
            case DeviceConnectionState.disconnecting:
              return _buildIng(
                snapshot.data.toString().split(".").last.toString(),
              );
            case DeviceConnectionState.disconnected:
              return Center(
                child: ElevatedButton(
                  onPressed: widget.commModel.connect,
                  child: const Text("Connect"),
                ),
              );
          }
        },
      ),
    );
  }

  Widget _buildIng(String state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8.0),
          Text(state),
        ],
      ),
    );
  }
}
