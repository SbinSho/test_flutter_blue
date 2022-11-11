import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  runApp(const FlutterBlueDemo());
}

class FlutterBlueDemo extends StatefulWidget {
  const FlutterBlueDemo({super.key});

  @override
  State<FlutterBlueDemo> createState() => _FlutterBlueDemoState();
}

class _FlutterBlueDemoState extends State<FlutterBlueDemo> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // You can request multiple permissions at once.
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.bluetoothScan,
      ].request();

      for (var element in statuses.entries) {
        if (element.value.isGranted) {
          continue;
        } else if (element.value.isDenied) {
          await element.key.request();
        } else if (element.value.isPermanentlyDenied) {
          openAppSettings();
        } else {
          exit(0);
        }
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: const TextTheme(
          bodyText2: TextStyle(),
        ),
      ),
      home: const DemoPage(title: 'Flutter Demo Home Page'),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key, required this.title});

  final String title;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _fBL = FlutterBluePlus.instance;

  Set<BluetoothDevice> devices = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: StreamBuilder<List<ScanResult>>(
            stream: _fBL.scanResults,
            initialData: const [],
            builder: (context, snapshot) {
              for (var element in snapshot.data!) {
                if (element.device.name != "") {
                  devices.add(element.device);
                }
              }

              var widgets = <Widget>[];

              for (var element in devices) {
                widgets.add(
                  ListTile(
                    title: Text(element.name),
                    subtitle: Text(element.id.id),
                    trailing: StreamBuilder<BluetoothDeviceState>(
                      stream: element.state,
                      initialData: BluetoothDeviceState.disconnected,
                      builder: (context, snapshot) {
                        switch (snapshot.data!) {
                          case BluetoothDeviceState.disconnected:
                            return ElevatedButton(
                              onPressed: element.connect,
                              child: const Text("connect"),
                            );
                          case BluetoothDeviceState.connecting:
                            return const CircularProgressIndicator(
                              color: Colors.red,
                            );
                          case BluetoothDeviceState.connected:
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: element.disconnect,
                              child: const Text("disconnect"),
                            );
                          case BluetoothDeviceState.disconnecting:
                            return const CircularProgressIndicator(
                              color: Colors.red,
                            );
                        }
                      },
                    ),
                  ),
                );
              }

              return Column(
                children: widgets,
              );
            },
          ),
        ),
      ),
      floatingActionButton: _buildActionBtn(),
    );
  }

  StreamBuilder<bool> _buildActionBtn() {
    return StreamBuilder<bool>(
      stream: _fBL.isScanning,
      initialData: false,
      builder: (context, snapshot) {
        if (snapshot.data! == true) {
          return FloatingActionButton(
            onPressed: _fBL.stopScan,
            child: const CircularProgressIndicator(color: Colors.red),
          );
        } else {
          return FloatingActionButton(
            onPressed: _fBL.startScan,
            child: const Icon(Icons.search),
          );
        }
      },
    );
  }
}
