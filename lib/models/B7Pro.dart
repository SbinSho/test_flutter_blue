// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../app_constant.dart';

class B7ProModel {
  static final B7ProModel _instance = B7ProModel();
  static B7ProModel get instance => _instance;

  final flutterReactiveBle = FlutterReactiveBle();

  // key : device.mac, value : device object
  Map<String, DiscoveredDevice> deviceInfo = {};

  final _bleScaning = StreamController<bool>.broadcast();
  final _devices = StreamController<Map<String, DiscoveredDevice>>.broadcast();
  StreamSubscription? _deviceScanSubscription;

  Stream<bool> get scanningState => _bleScaning.stream;
  Stream<Map<String, DiscoveredDevice>> get deviceState => _devices.stream;

  void scanStart([int scanningTime = 10]) {
    deviceInfo.clear();
    _bleScaning.add(true);
    _deviceScanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [
        Uuid.parse("00001800-0000-1000-8000-00805f9b34fb"),
        Uuid.parse("00002222-0000-1000-8000-00805f9b34fb"),
        Uuid.parse("0000fee7-0000-1000-8000-00805f9b34fb"),
      ],
      scanMode: ScanMode.lowLatency,
    ).listen(
      (device) {
        if (device.name != "") {
          if (!deviceInfo.containsKey(device.id)) {
            deviceInfo[device.id] = device;
            _devices.add(deviceInfo);
            _bleScaning.add(true);
          }
        }
      },
    );

    Timer(Duration(seconds: scanningTime), stopScan);
  }

  void stopScan() {
    _deviceScanSubscription?.cancel();
    _bleScaning.add(false);
  }

  Uint8List _int16To8List(int input) {
    return Uint8List.fromList([(input >> 8) & 0xFF, input & 0xff]);
  }
}

class B7ProModelProcess extends B7ProModel {
  String? deviceId;
  late DiscoveredDevice? device;
  StreamSubscription? _connectSubscription;

  B7ProModelProcess(this.device, this.deviceId);

  final _deviceConnectState = StreamController<ConnectionStateUpdate>();
  final _dataStream = StreamController<List<List<int>>>.broadcast();

  Stream<List<List<int>>> get data => _dataStream.stream;

  Stream<ConnectionStateUpdate> get connectState {
    _connectSubscription = flutterReactiveBle
        .connectToDevice(
      id: device!.id,
    )
        .listen(
      (state) {
        _deviceConnectState.add(state);
      },
      onDone: () {
        debugPrint("Device scan onDone");
      },
      onError: (Object e) {
        debugPrint("Device scan fails with error: $e");
        deviceDisConnect();
      },
    );

    return _deviceConnectState.stream;
  }

  void deviceDisConnect() {
    _connectSubscription?.cancel();
    _connectSubscription = null;
  }

  Timer? timer;

  void cancleTimer() {
    timer?.cancel();
  }

  QualifiedCharacteristic getQualifiedCharacteristic() =>
      QualifiedCharacteristic(
        characteristicId: B7ProCommServiceCharacteristicUuid.command,
        serviceId: B7ProServiceUuid.comm,
        deviceId: device!.id,
      );

  final bodyTemp = 0x24;
  final heartRate = 0xE5;
  final stepCount = 0XB1;
  final cmdStart = 0x11;
  final cmdStop = 0x00;

  void getData() async {
    final characteristic = getQualifiedCharacteristic();

    final dataChannel = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );

    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
        value: [bodyTemp, cmdStart]);

    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
        value: [heartRate, cmdStart]);

    /* await flutterReactiveBle
        .writeCharacteristicWithResponse(qAstepCount, value: [stepCount]); */

    List<List<int>> results = List<List<int>>.filled(3, [0]);
    flutterReactiveBle.subscribeToCharacteristic(dataChannel).listen(
      (event) {
        print("event : $event");
        if (event.length == 4) {
          results[0] = event;
        } else if (event.length == 13) {
          results[1] = event;
        } else if (event.length == 18) {
          results[2] = event;
        }

        timer = Timer(
          const Duration(seconds: 5),
          () {
            _dataStream.add(results);
          },
        );
      },
    );
  }
}
