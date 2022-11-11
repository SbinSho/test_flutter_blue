import 'package:flutter/material.dart';
import 'package:flutter_blue_test/b7pro_data_view.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import 'models/B7Pro.dart';

void main() {
  runApp(const ReactiveDemo());
}

class ReactiveDemo extends StatelessWidget {
  const ReactiveDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
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
                        final commModel = B7ProCommModel(element.value);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                B7ProDataView(commModel: commModel),
                          ),
                        );
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
              onPressed: () async {
                if (await checkPermission()) {
                  scanner.scanStart();
                }
              },
              child: const Icon(Icons.search),
            );
          }
        },
      );

  Future<bool> checkPermission() async {
    var locationStatus = Permission.location;
    var bleScanStatus = Permission.bluetoothScan;
    var bleConnectStatus = Permission.bluetoothConnect;

    final status = <Permission>[
      locationStatus,
      bleScanStatus,
      bleConnectStatus,
    ];

    for (var element in status) {
      if (await element.status.isDenied) {
        await element.request();
      } else if (await element.status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }

    for (var element in status) {
      if (!(await element.status.isGranted)) {
        return false;
      }
    }

    return true;
  }
}
