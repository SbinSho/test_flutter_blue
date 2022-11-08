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
  void initState() {
    scanner.flutterReactiveBle.connectedDeviceStream.listen((event) {
      print("event : ${event.deviceId}");
      print("event : ${event.connectionState}");
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DEMO"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /* StreamBuilder(
              stream: scanner.flutterReactiveBle.connectedDeviceStream,
              builder: (context, snapshot) {
                connectWidgets.clear();

                scanner.

                if (snapshot.data != null) {
                  final processModel =
                      B7ProModelProcess(null, snapshot.data!.deviceId);

                  connectWidgets.add(
                    InkWell(
                      onTap: () async {
                        await _showDialog(processModel);
                      },
                      child: ListTile(
                        title: Text(processModel.deviceId!),
                        subtitle: Text(processModel.deviceId!),
                        trailing: Text("rssi : ${processModel.deviceId}"),
                      ),
                    ),
                  );
                }

                return Column(
                  children: connectWidgets,
                );
              },
            ),
            const Divider(thickness: 3), */
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
    final model = B7ProTaskModel(device, null);
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('데이터 모니터링'),
          content: SingleChildScrollView(
            child: StreamBuilder<ConnectionStateUpdate>(
              stream: model.connectState,
              builder: (context, snapshot) {
                if (snapshot.data != null &&
                    snapshot.data!.connectionState ==
                        DeviceConnectionState.connected) {
                  model.getData();

                  return StreamBuilder<List<List<int>>>(
                    stream: model.data,
                    initialData: List<List<int>>.filled(3, [0]),
                    builder: (context, snapshot) {
                      var bytePacket = Uint8List.fromList(snapshot.data![1]);
                      if (snapshot.data![1][0] != 0) {
                        return Column(
                          children: [
                            Text('심박수 => ${snapshot.data![0].last}'),
                            Text(
                                '체온 => ${bytePacket.isNotEmpty ? ByteData.sublistView(bytePacket).getUint16(11) / 100.0 : 0}'),
                            Text('걸음수 => ${snapshot.data![2].last}'),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Text('심박수 => ${snapshot.data![0].last}'),
                          Text('체온 => ${0}'),
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
                model.deviceDisConnect();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
