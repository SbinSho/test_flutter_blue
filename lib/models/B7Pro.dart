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
  late DiscoveredDevice? device;

  final _bodyTemp = 0x24;
  final _heartRate = 0xE5;
  final _stepCount = 0XB1;
  final _btCmdStart = 0x01;
  final _hrCmdStart = 0x11;
  // final _hrCmdStop = 0x00;
  // command send 대기 시간
  final _sendCmdMs = 500;

  // data send task
  Future<void>? _task;
  final _resultDatas = List<List<int>>.filled(3, [0]);

  // band data stream
  final _dataStream = StreamController<List<List<int>>>.broadcast();
  StreamSubscription<List<int>>? _dataSubscription;
  Stream<List<List<int>>> get dataStream => _dataStream.stream;

  // connection state stream
  final _connectionStream = StreamController<DeviceConnectionState>();
  StreamSubscription<ConnectionStateUpdate>? _connectSubscription;
  Stream<DeviceConnectionState> get connectState => _connectionStream.stream;

  // connection timer
  Timer? _connectionTimer;
  final _connectionTimeout = const Duration(seconds: 10);

  B7ProTaskModel(this.device) {
    connect();
  }

  void connect() {
    try {
      _connectionTimer = Timer(_connectionTimeout, () {
        _connectionStream.add(DeviceConnectionState.disconnected);
        disConnect();
      });

      _connectSubscription = flutterReactiveBle.connectToDevice(
        id: device!.id,
        connectionTimeout: _connectionTimeout,
        servicesWithCharacteristicsToDiscover: {
          B7ProServiceUuid.comm: [
            B7ProCommServiceCharacteristicUuid.command,
            B7ProCommServiceCharacteristicUuid.rxNotify,
          ]
        },
      ).listen(
        (state) {
          if (state.connectionState == DeviceConnectionState.connected) {
            _connectionTimer?.cancel();
            _connectionTimer = null;
            _task = _startTask();
          }

          _connectionStream.add(state.connectionState);
        },
        onDone: () {
          disConnect();
          debugPrint("Device Connect onDone");
        },
        onError: (error) {
          disConnect();
          debugPrint("Device connectToDevice error: $error");
        },
      );

      _dataSubscription = flutterReactiveBle
          .subscribeToCharacteristic(getNotifyCharacteristic)
          .listen((event) {
        if (event.length == 4) {
          _resultDatas[0] = event;
        } else if (event.length == 13) {
          _resultDatas[1] = event;
        } else if (event.length == 18) {
          _resultDatas[2] = event;
        }

        _dataStream.add(_resultDatas);
      }, onDone: () {
        disConnect();
        debugPrint("Device SubscribeToCharacteristic onDone");
      }, onError: (error) {
        disConnect();
        debugPrint("Device SubscribeToCharacteristic onError : $error");
      });
    } catch (e) {
      debugPrint("Connect Error : $e");
    }
  }

  Future<void> disConnect() async {
    if (_task != null) {
      await _task;
      _task = null;
    }

    await _dataSubscription?.cancel();
    await _connectSubscription?.cancel();
    _connectSubscription = null;
    _dataSubscription = null;
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

  Future<void> _startTask() async {
    try {
      var taskList = [
        [_bodyTemp, _btCmdStart],
        [_heartRate, _hrCmdStart],
        [_stepCount],
      ];

      while (taskList.isNotEmpty) {
        await _sendCmd(taskList.first);
        taskList.removeAt(0);
        await Future.delayed(Duration(milliseconds: _sendCmdMs));
      }
    } catch (e) {
      debugPrint("Task Error :$e");
    }
  }

  Future<void> _sendCmd(List<int> value) async {
    final completer = Completer<void>();

    try {
      flutterReactiveBle
          .writeCharacteristicWithResponse(getComandCharacteristic,
              value: value)
          .then(
            (value) => completer.complete(),
          )
          .catchError((onError) {
        debugPrint("onError! : $onError");
      });
    } catch (e) {
      debugPrint("Send Cmd Error : $e");
      completer.complete();
    }

    return completer.future;
  }

  double parsingTempData(List<int> tempData) {
    if (tempData.length == 13) {
      var convertUnit8 = Uint8List.fromList(tempData);
      final ByteData byteData = ByteData.sublistView(convertUnit8);

      try {
        return byteData.getInt16(11) / 100.0;
      } catch (e) {
        debugPrint("parsingTemData Error : $e");
        return 0.0;
      }
    }

    return 0.0;
  }
}
