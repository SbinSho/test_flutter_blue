import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

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
  Map<String, DiscoveredDevice> devices = {};
  StreamSubscription? _subscription;

  late bool _isScanning;
  final scaning = StreamController<bool>.broadcast();

  @override
  void initState() {
    _isScanning = false;
    startScan();
    Future.delayed(const Duration(seconds: 10), stopScan);
    super.initState();
  }

  void startScan() {
    devices.clear();
    lastDevice.value = null;
    _isScanning = !_isScanning;
    scaning.add(_isScanning);

    _subscription = flutterReactiveBle.scanForDevices(withServices: [
      Uuid.parse("00001800-0000-1000-8000-00805f9b34fb"),
      Uuid.parse("00002222-0000-1000-8000-00805f9b34fb"),
      Uuid.parse("0000fee7-0000-1000-8000-00805f9b34fb"),
    ], scanMode: ScanMode.lowLatency).listen((device) {
      if (device.name != "") {
        if (!devices.containsKey(device.id)) {
          devices[device.id] = device;
          lastDevice.value = (device);
        }
      }
    });
  }

  void stopScan() {
    _subscription?.cancel();
    _subscription = null;
    _isScanning = !_isScanning;
    scaning.add(_isScanning);
  }

  void setTime() {
    /* Timer.periodic(const Duration(seconds: 3), (timer) {
            flutterReactiveBle
                .connectToDevice(id: device.id)
                .listen((event) async {
              if (event.connectionState == DeviceConnectionState.connected) {
                final tx = QualifiedCharacteristic(
                  characteristicId:
                      Uuid.parse("000033f1-0000-1000-8000-00805f9b34fb"),
                  serviceId: Uuid.parse("000055ff-0000-1000-8000-00805f9b34fb"),
                  deviceId: device.id,
                );

                var time = DateTime.now();
                await flutterReactiveBle
                    .writeCharacteristicWithResponse(tx, value: [
                  0xA3,
                  ..._int16To8List(time.year),
                  time.month,
                  time.day,
                  time.hour,
                  time.minute,
                  time.second,
                ]);
              }
            });
          },); */
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
                for (var element in devices.entries)
                  ListTile(
                    title: Text(element.value.name),
                    subtitle: Text(element.value.id),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        flutterReactiveBle
                            .connectToDevice(id: element.value.id)
                            .listen((sate) {
                          if (sate.connectionState ==
                              DeviceConnectionState.connected) {
                            final characteristic = QualifiedCharacteristic(
                              characteristicId: Uuid.parse(
                                  "000033f2-0000-1000-8000-00805f9b34fb"),
                              serviceId: Uuid.parse(
                                  "000055ff-0000-1000-8000-00805f9b34fb"),
                              deviceId: element.value.id,
                            );

                            flutterReactiveBle
                                .subscribeToCharacteristic(characteristic)
                                .listen((event) {
                              print("deviceName : ${element.value.name}");
                              for (var i in event) {
                                print(i);
                              }
                              /*  print(
                                  "event : ${String.fromCharCodes(event).characters}"); */
                            });
                          }
                        });
                      },
                      child: const Text("read"),
                    ),
                  )
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildActionBtn(),
    );
  }

  Uint8List _int16To8List(int input) {
    return Uint8List.fromList([(input >> 8) & 0xFF, input & 0xff]);
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
