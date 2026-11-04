import 'package:flutter/services.dart';

/// The Android window and settings calls UC-70 needs, behind one seam.
abstract interface class DeviceWindow {
  /// Blocks screenshots and screen recording of the current window while on.
  Future<void> setSecure(bool secure);

  /// Opens this app's notification settings. False when none could be opened.
  Future<bool> openNotificationSettings();

  /// Removes this app's notifications from the tray.
  Future<void> clearNotifications();
}

final class ChannelDeviceWindow implements DeviceWindow {
  const ChannelDeviceWindow();

  static const _channel = MethodChannel('com.tripmate.trip_mate_mobile/device');

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on PlatformException {
      // A window that cannot be secured must not block an emergency action.
    } on MissingPluginException {
      // Android only: other platforms have no secure-window call here.
    }
  }

  @override
  Future<void> clearNotifications() async {
    try {
      await _channel.invokeMethod<void>('clearNotifications');
    } on PlatformException {
      // Sign-out must complete even if the tray could not be cleared.
    } on MissingPluginException {
      // Android only: other platforms have no tray call here.
    }
  }

  @override
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
