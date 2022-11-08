// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../app_constant.dart';

class B7ProScanModel {
  static final B7ProScanModel _instance = B7ProScanModel();
  static B7ProScanModel get instance => _instance;

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
}

class B7ProTaskModel extends B7ProScanModel {
  StreamSubscription? _connectSubscription;
  late DiscoveredDevice? device;

  final _bodyTemp = 0x24;
  final _heartRate = 0xE5;
  final _stepCount = 0XB1;
  final _btCmdStart = 0x01;
  final _hrCmdStart = 0x11;
  final _hrCmdStop = 0x00;

  Timer? _taskTimer;
  Future<void>? _task;

  final _deviceConnectState = StreamController<ConnectionStateUpdate>();
  final _dataStream = StreamController<List<List<int>>>.broadcast();

  B7ProTaskModel(this.device);

  Stream<List<List<int>>> get data {
    _startGetData();
    return _dataStream.stream;
  }

  Stream<ConnectionStateUpdate> get connectState {
    print("tt");
    _connectSubscription = flutterReactiveBle
        .connectToDevice(
      id: device!.id,
    )
        .listen(
      (state) {
        debugPrint("connect : $state");
        _deviceConnectState.add(state);
      },
      onDone: () {
        debugPrint("Device Connect onDone");
      },
      onError: (Object e) {
        debugPrint("Device Connect fails with error: $e");
        deviceDisConnect();
      },
    );

    return _deviceConnectState.stream;
  }

  Future<void> deviceDisConnect() async {
    if (_task != null) {
      await _task;
      _taskTimer?.cancel();
    }
    await _connectSubscription?.cancel();
    _connectSubscription = null;
    /* await _deviceConnectState.close(); */
  }

  QualifiedCharacteristic get getComandCharacteristic =>
      QualifiedCharacteristic(
        characteristicId: B7ProCommServiceCharacteristicUuid.command,
        serviceId: B7ProServiceUuid.comm,
        deviceId: device!.id,
      );

  QualifiedCharacteristic get getNotifyCharacteristic =>
      QualifiedCharacteristic(
        characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
        serviceId: B7ProServiceUuid.comm,
        deviceId: device!.id,
      );

  void _startGetData() {
    print("startData");
    List<List<int>> results = List<List<int>>.filled(3, [0]);
    flutterReactiveBle
        .subscribeToCharacteristic(getNotifyCharacteristic)
        .listen(
      (event) {
        if (event.length == 4) {
          results[0] = event;
        } else if (event.length == 13) {
          results[1] = event;
        } else if (event.length == 18) {
          results[2] = event;
        }

        _dataStream.add(results);
      },
    );

    _taskTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) {
        _task = _getTask();
      },
    );

    /* await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
        value: [heartRate, hrCmdStop]); */
  }

  Future<void> _getTask() async {
    try {
      await flutterReactiveBle.writeCharacteristicWithResponse(
          getComandCharacteristic,
          value: [_bodyTemp, _btCmdStart]);

      await flutterReactiveBle.writeCharacteristicWithResponse(
          getComandCharacteristic,
          value: [_heartRate, _hrCmdStart]);

      await flutterReactiveBle.writeCharacteristicWithResponse(
          getComandCharacteristic,
          value: [_stepCount]);
    } catch (e) {
      debugPrint("Task Error :$e");
    }
  }

  double parsingTempData(List<int> tempData) {
    if (tempData.length == 13) {
      var convertUnit8 = Uint8List.fromList(tempData);
      final ByteData byteData = ByteData.sublistView(convertUnit8);

      try {
        return byteData.getInt16(11) / 100.0;
      } catch (e) {
        debugPrint("parsingTemData Error : $e");
        return 0;
      }
    }

    return 0.0;
  }
}
