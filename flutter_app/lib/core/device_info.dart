import 'package:flutter/services.dart';

/// Detects the true device form factor via a native Android platform channel.
///
/// Queried once at startup (see [init]) and cached as a static field so
/// every call-site can read [DeviceInfo.isTV] without a BuildContext.
///
/// Detection strategy (two layers):
///   1. Native: UiModeManager.currentModeType == UI_MODE_TYPE_TELEVISION
///   2. Fallback: false (caller may supplement with MediaQuery width check)
class DeviceInfo {
  DeviceInfo._();

  static const _channel = MethodChannel('mystreamtv/device');

  /// True when the OS reports the device is a TV (Android TV / Google TV).
  /// Always false on non-Android platforms (desktop, web).
  static bool isTV = false;

  /// Call once in [main()] before [runApp()] — after
  /// [WidgetsFlutterBinding.ensureInitialized()].
  static Future<void> init() async {
    try {
      final result = await _channel.invokeMethod<bool>('isTV');
      isTV = result ?? false;
    } on MissingPluginException {
      // Running on desktop (Windows/Linux dev environment) — not a TV.
      isTV = false;
    } catch (_) {
      // Any other native error: safe fallback.
      isTV = false;
    }
  }
}
