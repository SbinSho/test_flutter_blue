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

  Stream<List<int>> getBodyTemp() {
    final characteristic = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.command,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );

    final data = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );
    tempTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      flutterReactiveBle.writeCharacteristicWithResponse(
        characteristic,
        value: [0x24, 0x01],
      );
    });

    return flutterReactiveBle.subscribeToCharacteristic(data);
  }

  Timer? tempTimer;

  Stream<List<int>> getHeartRate() {
    final characteristic = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.command,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );

    final data = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );
    /* tempTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      flutterReactiveBle.writeCharacteristicWithResponse(
        characteristic,
        value: [0xE5],
      );
    }); */
    flutterReactiveBle.writeCharacteristicWithResponse(
      characteristic,
      value: [0xE5, 0xE511],
    );
    return flutterReactiveBle.subscribeToCharacteristic(data);
  }

  void cancleTimer() {
    tempTimer?.cancel();
  }

  Stream<List<int>> getStepCount() {
    final characteristic = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.command,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );

    final data = QualifiedCharacteristic(
      characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
      serviceId: B7ProServiceUuid.comm,
      deviceId: device!.id,
    );
    tempTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      flutterReactiveBle.writeCharacteristicWithResponse(
        characteristic,
        value: [0xB1],
      );
    });

    return flutterReactiveBle.subscribeToCharacteristic(data);
  }
}
