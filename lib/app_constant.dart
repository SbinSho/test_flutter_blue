import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class B7ProServiceUuid {
  // Commuication Service UUID
  static final comm = Uuid.parse("000055ff-0000-1000-8000-00805f9b34fb");
}

class B7ProCommServiceCharacteristicUuid {
  // 명령 채널
  static final command = Uuid.parse("000033f1-0000-1000-8000-00805f9b34fb");

  // 알림 채널
  static final rxNotify = Uuid.parse("000033f2-0000-1000-8000-00805f9b34fb");
}
