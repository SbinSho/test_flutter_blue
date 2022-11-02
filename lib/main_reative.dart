import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

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
  final flutterReactiveBle = FlutterReactiveBle();

  ValueNotifier<DiscoveredDevice?> lastDevice = ValueNotifier(null);
  Set<DiscoveredDevice> devices = {};
  StreamSubscription? _subscription;

  late bool _isScanning;
  final scaning = StreamController<bool>.broadcast();

  @override
  void initState() {
    _isScanning = true;
    scaning.add(_isScanning);
    startScan();
    Future.delayed(const Duration(seconds: 10), stopScan);

    super.initState();
  }

  void startScan() {
    devices.clear();
    lastDevice.value = null;
    _isScanning = !_isScanning;
    scaning.add(_isScanning);

    _subscription = flutterReactiveBle.scanForDevices(
        withServices: [], scanMode: ScanMode.lowLatency).listen((device) {
      if (device.name != "") {
        devices.add(device);
        lastDevice.value = (device);
      }
    });
  }

  void stopScan() {
    _subscription?.cancel();
    _subscription = null;
    _isScanning = !_isScanning;
    scaning.add(_isScanning);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("DEMO"),
      ),
      body: SingleChildScrollView(
        child: ValueListenableBuilder(
          valueListenable: lastDevice,
          builder: (context, value, child) {
            return Column(
              children: [
                for (var element in devices)
                  ListTile(
                    title: Text(element.name),
                    subtitle: Text(element.id),
                  )
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildActionBtn(),
    );
  }

  Widget _buildActionBtn() => StreamBuilder<bool>(
        stream: scaning.stream,
        initialData: true,
        builder: (context, snapshot) {
          if (snapshot.data!) {
            return FloatingActionButton(
              onPressed: stopScan,
              child: const CircularProgressIndicator(color: Colors.red),
            );
          } else {
            return FloatingActionButton(
              onPressed: startScan,
              child: const Icon(Icons.search),
            );
          }
        },
      );
}
