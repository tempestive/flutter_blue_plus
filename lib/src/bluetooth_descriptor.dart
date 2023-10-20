// Copyright 2017-2023, Charles Weinberger & Paul DeMarco.
// All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of flutter_blue_plus;

class BluetoothDescriptor {
  final DeviceIdentifier remoteId;
  final Guid serviceUuid;
  final Guid characteristicUuid;
  final Guid descriptorUuid;

  /// convenience accessor
  Guid get uuid => descriptorUuid;

  /// convenience accessor
  BluetoothDevice get device => BluetoothDevice(remoteId: remoteId);

  /// this variable is updated:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  List<int> get lastValue {
    String key = "$serviceUuid:$characteristicUuid:$descriptorUuid";
    return FlutterBluePlus._lastDescs[remoteId]?[key] ?? [];
  }

  /// this stream emits values:
  ///   - anytime `read()` is called
  ///   - anytime `write()` is called
  ///   - and when first listened to, it re-emits the last value for convenience
  Stream<List<int>> get lastValueStream => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnDescriptorRead" || m.method == "OnDescriptorWritten")
      .map((m) => m.arguments)
      .map((args) => BmDescriptorData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.descriptorUuid == descriptorUuid)
      .where((p) => p.success == true)
      .map((p) => p.value)
      .newStreamWithInitialValue(lastValue);

  /// this stream emits values:
  ///   - anytime `read()` is called
  Stream<List<int>> get onValueReceived => FlutterBluePlus._methodStream.stream
      .where((m) => m.method == "OnDescriptorRead")
      .map((m) => m.arguments)
      .map((args) => BmDescriptorData.fromMap(args))
      .where((p) => p.remoteId == remoteId.toString())
      .where((p) => p.characteristicUuid == characteristicUuid)
      .where((p) => p.serviceUuid == serviceUuid)
      .where((p) => p.descriptorUuid == descriptorUuid)
      .where((p) => p.success == true)
      .map((p) => p.value);

  BluetoothDescriptor.fromProto(BmBluetoothDescriptor p)
      : remoteId = DeviceIdentifier(p.remoteId),
        serviceUuid = p.serviceUuid,
        characteristicUuid = p.characteristicUuid,
        descriptorUuid = p.descriptorUuid;

  /// Retrieves the value of a specified descriptor
  Future<List<int>> read({int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "readDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single read to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight requests and we wouldn't know which response is for us.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":readDesc";
    _Mutex readMutex = await _MutexFactory.getMutexForKey(key);
    await readMutex.take();

    // return value
    List<int> readValue = [];

    try {
      var request = BmReadDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
      );

      Stream<BmDescriptorData> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorRead")
          .map((m) => m.arguments)
          .map((args) => BmDescriptorData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid)
          .where((p) => p.descriptorUuid == request.descriptorUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDescriptorData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('readDescriptor', request.toMap());

      // wait for response
      BmDescriptorData response = await futureResponse
          .fbpEnsureAdapterIsOn("readDescriptor")
          .fbpEnsureDeviceIsConnected(device, "readDescriptor")
          .fbpTimeout(timeout, "readDescriptor");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "readDescriptor", response.errorCode, response.errorString);
      }

      readValue = response.value;
    } finally {
      readMutex.give();
    }

    return readValue;
  }

  /// Writes the value of a descriptor
  Future<void> write(List<int> value, {int timeout = 15}) async {
    // check connected
    if (FlutterBluePlus._isDeviceConnected(remoteId) == false) {
      throw FlutterBluePlusException(
          ErrorPlatform.dart, "writeDescriptor", FbpErrorCode.deviceIsDisconnected.index, "device is not connected");
    }

    // Only allow a single write to be underway at any time, per-characteristic, per-device.
    // Otherwise, there would be multiple in-flight requests and we wouldn't know which response is for us.
    String key = remoteId.str + ":" + characteristicUuid.toString() + ":writeDesc";
    _Mutex writeMutex = await _MutexFactory.getMutexForKey(key);
    await writeMutex.take();

    try {
      var request = BmWriteDescriptorRequest(
        remoteId: remoteId.toString(),
        serviceUuid: serviceUuid,
        secondaryServiceUuid: null,
        characteristicUuid: characteristicUuid,
        descriptorUuid: descriptorUuid,
        value: value,
      );

      Stream<BmDescriptorData> responseStream = FlutterBluePlus._methodStream.stream
          .where((m) => m.method == "OnDescriptorWritten")
          .map((m) => m.arguments)
          .map((args) => BmDescriptorData.fromMap(args))
          .where((p) => p.remoteId == request.remoteId)
          .where((p) => p.serviceUuid == request.serviceUuid)
          .where((p) => p.characteristicUuid == request.characteristicUuid)
          .where((p) => p.descriptorUuid == request.descriptorUuid);

      // Start listening now, before invokeMethod, to ensure we don't miss the response
      Future<BmDescriptorData> futureResponse = responseStream.first;

      // invoke
      await FlutterBluePlus._invokeMethod('writeDescriptor', request.toMap());

      // wait for response
      BmDescriptorData response = await futureResponse
          .fbpEnsureAdapterIsOn("writeDescriptor")
          .fbpEnsureDeviceIsConnected(device, "writeDescriptor")
          .fbpTimeout(timeout, "writeDescriptor");

      // failed?
      if (!response.success) {
        throw FlutterBluePlusException(_nativeError, "writeDescriptor", response.errorCode, response.errorString);
      }
    } finally {
      writeMutex.give();
    }

    return Future.value();
  }

  @override
  String toString() {
    return 'BluetoothDescriptor{'
        'remoteId: $remoteId, '
        'serviceUuid: $serviceUuid, '
        'characteristicUuid: $characteristicUuid, '
        'descriptorUuid: $descriptorUuid, '
        'lastValue: $lastValue'
        '}';
  }

  @Deprecated('Use onValueReceived instead')
  Stream<List<int>> get value => onValueReceived;

  @Deprecated('Use remoteId instead')
  DeviceIdentifier get deviceId => remoteId;
}
