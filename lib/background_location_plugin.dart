import 'dart:async';

import 'package:flutter/services.dart';

import 'background_location_plugin_platform_interface.dart';

class BackgroundLocationPlugin {
  static const MethodChannel _channel =
      MethodChannel('background_location_plugin');
  static final StreamController<Map<String, dynamic>> _locationController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<String> _resultController =
      StreamController<String>.broadcast();
  static final StreamController<Map<dynamic, dynamic>> _statusController =
      StreamController<Map<dynamic, dynamic>>.broadcast();
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'locationUpdate':
          _locationController.add(Map<String, dynamic>.from(call.arguments));
          break;
        case 'verificationResult':
          final Map<dynamic, dynamic> data = call.arguments;
          _resultController.add(data['status']);
          break;
        case 'authorizationStatusChanged':
          print("Authorization status changed: ${call.arguments}");
          break;
        case 'locationError':
          print("Location error: ${call.arguments}");
          break;
        case 'totalTimeInside':
          print("Total time inside buffer: ${call.arguments}");
          break;
      }
    });

    _isInitialized = true;
  }

  /// Get stream of location updates
  static Stream<Map<String, dynamic>> get locationStream {
    init();
    return _locationController.stream;
  }

  /// Get stream of verification results
  static Stream<String> get resultStream {
    init();
    return _resultController.stream;
  }

  static Stream<Map<dynamic, dynamic>> get statusStream {
    init();
    return _statusController.stream;
  }

  /// Start location verification service
  static Future<String> startService({
    required double targetLat,
    required double targetLng,
    required double bufferRadius,
    required double verificationWindow,
    required double verificationThreshold,
  }) async {
    init();

    try {
      final result = await _channel.invokeMethod('startService', {
        'targetLat': targetLat,
        'targetLng': targetLng,
        'bufferRadius': bufferRadius,
        'verificationWindow': verificationWindow,
        'verificationThreshold': verificationThreshold,
      });

      return result;
    } on PlatformException catch (e) {
      return "Failed to start service: ${e.message}";
    }
  }

  /// Stop location verification service
  static Future<String> stopService() async {
    try {
      final result = await _channel.invokeMethod('stopService');
      return result;
    } on PlatformException catch (e) {
      return "Failed to stop service: ${e.message}";
    }
  }

  /// Get current verification status
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getVerificationStatus');
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      return {
        "error": e.message,
        "isRunning": false,
      };
    }
  }

  /// Dispose resources
  static void dispose() {
    _locationController.close();
    _resultController.close();
    _isInitialized = false;
  }

  Future<void> startLocationService() async {
    try {
      await BackgroundLocationPluginPlatform.instance.startLocationService();
    } on PlatformException catch (e) {
      print("Failed to start service: '${e.message}'.");
    }
  }

  Future<void> stopLocationService() async {
    try {
      await BackgroundLocationPluginPlatform.instance.stopLocationService();
    } on PlatformException catch (e) {
      print("Failed to stop service: '${e.message}'.");
    }
  }

  // Future<String?> getPlatformVersion() {
  //   return BackgroundLocationPluginPlatform.instance.getPlatformVersion();
  // }
}
