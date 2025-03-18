import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'background_location_plugin_platform_interface.dart';

/// An implementation of [BackgroundLocationPluginPlatform] that uses method channels.
class MethodChannelBackgroundLocationPlugin
    extends BackgroundLocationPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('background_location_plugin');

  // @override
  // Future<String?> getPlatformVersion() async {
  //   final version =
  //       await methodChannel.invokeMethod<String>('getPlatformVersion');
  //   return version;
  // }

  @override
  Future<void> startLocationService() async {
    await methodChannel.invokeMethod('startService');
  }

  @override
  Future<void> stopLocationService() async {
    await methodChannel.invokeMethod('stopService');
  }
}
