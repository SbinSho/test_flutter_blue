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

  final _bleScaningStream = StreamController<bool>.broadcast();
  final _devicesStream =
      StreamController<Map<String, DiscoveredDevice>>.broadcast();
  StreamSubscription? _deviceScanSubscription;

  Stream<bool> get scanningState => _bleScaningStream.stream;
  Stream<Map<String, DiscoveredDevice>> get deviceState =>
      _devicesStream.stream;

  void scanStart([int scanningTime = 10]) {
    deviceInfo.clear();
    _bleScaningStream.add(true);
    _deviceScanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [
        B7ProAdvertisedServiceUuid.service1,
        B7ProAdvertisedServiceUuid.service2,
        B7ProAdvertisedServiceUuid.service3,
      ],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      if (device.name != "") {
        if (!deviceInfo.containsKey(device.id)) {
          deviceInfo[device.id] = device;
          _devicesStream.add(deviceInfo);
          _bleScaningStream.add(true);
        }
      }
    }, onError: (error) {
      debugPrint("Scan Device Error : $error");
    });

    Timer(Duration(seconds: scanningTime), stopScan);
  }

  void stopScan() {
    _deviceScanSubscription?.cancel();
    _bleScaningStream.add(false);
  }
}

class B7ProTaskModel extends B7ProScanModel {
  late DiscoveredDevice? device;

  final _bodyTemp = 0x24;
  final _heartRate = 0xE5;
  final _stepCount = 0XB1;
  final _btCmdStart = 0x01;
  final _hrCmdStart = 0x11;
  final _hrCmdStop = 0x00;
  // command send 대기 시간
  final _sendCmdMs = 500;

  // data send task
  Future<void>? _task;
  final _bandStreamDatas = List<List<int>>.filled(3, [0]);

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

  Future<void> connect() async {
    _connectionTimer = Timer(_connectionTimeout, () {
      debugPrint("connection timeout.");
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
          // Connection timeout timer cancle
          _connectionTimer?.cancel();
          _connectionTimer = null;
          // band response data subscription
          _dataSubscription = _getDataSubscription();
          // band request data commnad
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

  StreamSubscription<List<int>> _getDataSubscription() => flutterReactiveBle
          .subscribeToCharacteristic(getNotifyCharacteristic)
          .listen(
        (data) {
          debugPrint("data length : ${data.length}");
          debugPrint("data : $data");
          if (data.length == 4) {
            _bandStreamDatas[0] = data;
          } else if (data.length == 13) {
            _bandStreamDatas[1] = data;
          } else if (data.length == 18) {
            _bandStreamDatas[2] = data;
          }

          _dataStream.add(_bandStreamDatas);
        },
        onDone: () {
          debugPrint("Device SubscribeToCharacteristic onDone");
        },
        onError: (error) {
          debugPrint("Device SubscribeToCharacteristic onError : $error");
        },
      );

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
      var commnads = [
        [_bodyTemp, _btCmdStart],
        [_heartRate, _hrCmdStart],
        [_stepCount],
      ];

      var cleanCommands = [
        [_heartRate, _hrCmdStop]
      ];

      while (commnads.isNotEmpty) {
        await _sendCmd(commnads.first);
        commnads.removeAt(0);
        await Future.delayed(Duration(milliseconds: _sendCmdMs));
      }

      while (cleanCommands.isNotEmpty) {
        await _sendCmd(cleanCommands.first);
        cleanCommands.removeAt(0);
        await Future.delayed(Duration(milliseconds: _sendCmdMs));
      }
    } catch (e) {
      debugPrint("Task Error :$e");
    }
  }

  Future<void> _sendCmd(List<int> value) async {
    final completer = Completer<void>();

    flutterReactiveBle
        .writeCharacteristicWithResponse(getComandCharacteristic, value: value)
        .then(
          (value) => completer.complete(),
        )
        .catchError(
      (onError) {
        debugPrint("onError! : $onError");
      },
    );

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
