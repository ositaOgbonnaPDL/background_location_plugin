import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'background_location_plugin_method_channel.dart';

abstract class BackgroundLocationPluginPlatform extends PlatformInterface {
  /// Constructs a BackgroundLocationPluginPlatform.
  BackgroundLocationPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static BackgroundLocationPluginPlatform _instance =
      MethodChannelBackgroundLocationPlugin();

  /// The default instance of [BackgroundLocationPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelBackgroundLocationPlugin].
  static BackgroundLocationPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BackgroundLocationPluginPlatform] when
  /// they register themselves.
  static set instance(BackgroundLocationPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // Future<String?> getPlatformVersion() {
  //   throw UnimplementedError('platformVersion() has not been implemented.');
  // }

  Future<void> startLocationService() {
    throw UnimplementedError(
        'startLocationService() has not been implemented.');
  }

  Future<void> stopLocationService() {
    throw UnimplementedError('stopLocationService() has not been implemented.');
  }
}
