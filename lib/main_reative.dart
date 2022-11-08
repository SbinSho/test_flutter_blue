import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import 'models/B7Pro.dart';

void main() {
  runApp(const ReactiveDemo());
}

class ReactiveDemo extends StatelessWidget {
  const ReactiveDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final B7ProScanModel scanner = B7ProScanModel.instance;
  final connectWidgets = <Widget>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DEMO"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            StreamBuilder<Map<String, DiscoveredDevice>>(
              stream: scanner.deviceState,
              initialData: const {},
              builder: (context, snapshot) {
                var widgets = <Widget>[];

                for (var element in snapshot.data!.entries) {
                  widgets.add(
                    InkWell(
                      onTap: () {
                        _showDialog(element.value);
                      },
                      child: ListTile(
                        title: Text(element.value.name),
                        subtitle: Text(element.value.id),
                        trailing: Text("rssi : ${element.value.rssi}"),
                      ),
                    ),
                  );
                }

                return Column(
                  children: widgets,
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _buildActionBtn(),
    );
  }

  Widget _buildActionBtn() => StreamBuilder(
        stream: scanner.scanningState,
        initialData: false,
        builder: (context, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              onPressed: scanner.stopScan,
              child: const CircularProgressIndicator(color: Colors.red),
            );
          } else {
            return FloatingActionButton(
              onPressed: scanner.scanStart,
              child: const Icon(Icons.search),
            );
          }
        },
      );
  Future<void> _showDialog(DiscoveredDevice device) {
    final taskModel = B7ProTaskModel(device);
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        print("test");
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const Text('데이터 모니터링'),
              Text(taskModel.device!.name),
            ],
          ),
          content: SingleChildScrollView(
            child: StreamBuilder<ConnectionStateUpdate>(
              stream: taskModel.connectState,
              builder: (context, snapshot) {
                print("state : ${snapshot.data?.connectionState}");
                if (snapshot.data != null &&
                    snapshot.data!.connectionState ==
                        DeviceConnectionState.connected) {
                  return StreamBuilder<List<List<int>>>(
                    stream: taskModel.data,
                    initialData: List<List<int>>.filled(3, [0]),
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text('심박수 => ${snapshot.data![0].last}'),
                          Text(
                              '체온 => ${taskModel.parsingTempData(snapshot.data![1])}'),
                          Text('걸음수 => ${snapshot.data![2].last}'),
                        ],
                      );
                    },
                  );
                } else {
                  return Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                          "${snapshot.data?.connectionState.toString().split(".").last}"),
                    ],
                  );
                }
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('종료'),
              onPressed: () {
                taskModel
                    .deviceDisConnect()
                    .then((value) => Navigator.of(context).pop());
              },
            ),
          ],
        );
      },
    );
  }
}
