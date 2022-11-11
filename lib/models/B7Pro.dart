// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../app_constant.dart';

class B7ProScanModel {
  static final B7ProScanModel _instance = B7ProScanModel._();
  static B7ProScanModel get instance => _instance;

  B7ProScanModel._();

  final _reactiveBle = FlutterReactiveBle();

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
    _deviceScanSubscription = _reactiveBle.scanForDevices(
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

class B7ProDataModel {
  late final String deviceMac;

  B7ProDataModel(this.deviceMac);

  final _heartStream = StreamController<double>.broadcast();
  final _tempStream = StreamController<double>.broadcast();
  final _stepStream = StreamController<double>.broadcast();

  Stream<double> get heartStream => _heartStream.stream;
  Stream<double> get tempStream => _tempStream.stream;
  Stream<double> get stepStream => _stepStream.stream;

  void updateStream(List<int> data) {
    if (data.length == 4) {
      _heartStream.add(data.last.toDouble());
    } else if (data.length == 13) {
      _tempStream.add(_parsingTempData(data));
    } else if (data.length == 18) {
      _stepStream.add(data.last.toDouble());
    }
  }

  double _parsingTempData(List<int> tempData) {
    if (tempData.length == 13) {
      var convertUnit8 = Uint8List.fromList(tempData);
      final ByteData byteData = ByteData.sublistView(convertUnit8);

      return byteData.getInt16(11) / 100.0;
    }

    return 0.0;
  }
}

class B7ProCommModel {
  late DiscoveredDevice device;
  late B7ProDataModel _dataModel;

  final _reactiveBle = FlutterReactiveBle();
  final _bodyTemp = 0x24;
  final _heartRate = 0xE5;
  final _stepCount = 0XB1;
  final _btCmdStart = 0x01;
  final _hrCmdStart = 0x11;
  final _hrCmdStop = 0x00;
  // command send 대기 시간
  final _sendCmdMs = 1000;

  // final _bandStreamDatas = List<List<int>>.filled(3, [0]);

  // band data stream
  StreamSubscription<List<int>>? _dataSubscription;

  Stream<double> get heartStream => _dataModel.heartStream;
  Stream<double> get tempStream => _dataModel.tempStream;
  Stream<double> get stepStream => _dataModel.stepStream;

  // final _dataStream = StreamController<List<List<int>>>.broadcast();
  // Stream<List<List<int>>> get dataStream => _dataStream.stream;

  // connection state stream
  final _connectionStream = StreamController<DeviceConnectionState>.broadcast();
  StreamSubscription<ConnectionStateUpdate>? _connectSubscription;
  Stream<DeviceConnectionState> get connectState => _connectionStream.stream;
  bool isConnected = false;

  // device connection timer
  Timer? _connectionTimer;
  final _connectionTimeout = const Duration(seconds: 10);

  // device data request timer
  Timer? _taskTimer;
  int _taskInterval = 10;
  ValueNotifier<Future<void>?> taskRunning = ValueNotifier<Future<void>?>(null);

  B7ProCommModel(DiscoveredDevice inputDevice) {
    device = inputDevice;
    _dataModel = B7ProDataModel(device.id);
    // connect();
  }

  StreamSubscription<List<int>> get _getDataSubscription =>
      _reactiveBle.subscribeToCharacteristic(_getNotifyCharacteristic).listen(
        (data) {
          debugPrint("data length : ${data.length}");
          debugPrint("data : $data");
          if (taskRunning.value != null) {
            _dataModel.updateStream(data);
          }
        },
        onDone: () {
          debugPrint("Device SubscribeToCharacteristic onDone");
        },
        onError: (error) {
          debugPrint("Device SubscribeToCharacteristic onError : $error");
        },
      );

  QualifiedCharacteristic get _getComandCharacteristic =>
      QualifiedCharacteristic(
        characteristicId: B7ProCommServiceCharacteristicUuid.command,
        serviceId: B7ProServiceUuid.comm,
        deviceId: device.id,
      );

  QualifiedCharacteristic get _getNotifyCharacteristic =>
      QualifiedCharacteristic(
        characteristicId: B7ProCommServiceCharacteristicUuid.rxNotify,
        serviceId: B7ProServiceUuid.comm,
        deviceId: device.id,
      );

  Future<void> connect() async {
    _connectionTimer = Timer(_connectionTimeout, () {
      debugPrint("connection timeout.");
      _connectionStream.add(DeviceConnectionState.disconnected);
      disConnect();
    });

    _connectSubscription = _reactiveBle.connectToDevice(
      id: device.id,
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
          _dataSubscription = _getDataSubscription;

          isConnected = true;
        }

        _connectionStream.add(state.connectionState);
      },
      onDone: () {
        debugPrint("Device Connect onDone");
        _connectionTimer?.cancel();
        _connectionTimer = null;
        disConnect();
      },
      onError: (error) {
        debugPrint("Device connectToDevice error: $error");
        _connectionTimer?.cancel();
        _connectionTimer = null;
        disConnect();
      },
    );
  }

  Future<void> disConnect() async {
    debugPrint("B7Pro DisConnect!");
    isConnected = false;
    await stopTask();
    await _dataSubscription?.cancel();
    await _connectSubscription?.cancel();
    _connectSubscription = null;
    _dataSubscription = null;
  }

  void taskIntervalChange(int interval) async {
    _taskInterval = interval;
    await stopTask();
    await startTask();
  }

  Future<void> startTask() async {
    await stopTask();
    debugPrint("B7Pro Start Task!");
    if (isConnected) {
      taskRunning.value = _runTask();
      _taskTimer = Timer.periodic(
        Duration(seconds: _taskInterval),
        (timer) {
          taskRunning.value = _runTask();
        },
      );
    }
  }

  Future<void> stopTask() async {
    debugPrint("B7Pro Stop Task!");
    final completer = Completer<void>();

    _taskTimer?.cancel();
    if (taskRunning.value != null) {
      taskRunning.value!.then((value) {
        taskRunning.value = null;
        completer.complete();
      });
    } else {
      completer.complete();
    }

    return completer.future;
  }

  Future<void> _runTask() async {
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

    _reactiveBle
        .writeCharacteristicWithResponse(_getComandCharacteristic, value: value)
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
}
