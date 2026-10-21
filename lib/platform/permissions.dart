import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum PermissionState { granted, needed, permanentlyDenied }

abstract class Permissions {
  Future<PermissionState> bluetooth();
  Future<PermissionState> requestBluetooth();
  Future<void> openSettings();
  Future<bool> notificationsGranted();
  Future<void> requestNotifications();

  static Permissions forPlatform() =>
      Platform.isAndroid ? AndroidPermissions() : GrantedPermissions();
}

class GrantedPermissions implements Permissions {
  @override
  Future<PermissionState> bluetooth() async => PermissionState.granted;
  @override
  Future<PermissionState> requestBluetooth() async => PermissionState.granted;
  @override
  Future<void> openSettings() async {}
  @override
  Future<bool> notificationsGranted() async => true;
  @override
  Future<void> requestNotifications() async {}
}

/// Nearby devices only: BLUETOOTH_SCAN is declared `neverForLocation`, so
/// Android never asks for location.
class AndroidPermissions implements Permissions {
  static const _ble = [Permission.bluetoothScan, Permission.bluetoothConnect];

  // Android only reports "permanently denied" in a request's result; a later
  // status check reads plain "denied" again.
  bool _deniedForGood = false;

  PermissionState _fold(Iterable<PermissionStatus> statuses) {
    if (statuses.every((s) => s.isGranted)) return PermissionState.granted;
    if (statuses.any((s) => s.isPermanentlyDenied)) {
      return PermissionState.permanentlyDenied;
    }
    return PermissionState.needed;
  }

  @override
  Future<PermissionState> bluetooth() async {
    final state = _fold([for (final p in _ble) await p.status]);
    if (state == PermissionState.granted) _deniedForGood = false;
    if (state == PermissionState.needed && _deniedForGood) {
      return PermissionState.permanentlyDenied;
    }
    return state;
  }

  @override
  Future<PermissionState> requestBluetooth() async {
    final state = _fold((await _ble.request()).values);
    _deniedForGood = state == PermissionState.permanentlyDenied;
    return state;
  }

  @override
  Future<void> openSettings() => openAppSettings();

  @override
  Future<bool> notificationsGranted() => Permission.notification.isGranted;

  @override
  Future<void> requestNotifications() => Permission.notification.request();
}

/// For the simulated device: Bluetooth needs no permission, notifications
/// are real.
class SimulatedPermissions implements Permissions {
  SimulatedPermissions(this._real);
  final Permissions _real;

  @override
  Future<PermissionState> bluetooth() async => PermissionState.granted;
  @override
  Future<PermissionState> requestBluetooth() async => PermissionState.granted;
  @override
  Future<void> openSettings() => _real.openSettings();
  @override
  Future<bool> notificationsGranted() => _real.notificationsGranted();
  @override
  Future<void> requestNotifications() => _real.requestNotifications();
}
