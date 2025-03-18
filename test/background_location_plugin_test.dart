// import 'package:flutter_test/flutter_test.dart';
// import 'package:background_location_plugin/background_location_plugin.dart';
// import 'package:background_location_plugin/background_location_plugin_platform_interface.dart';
// import 'package:background_location_plugin/background_location_plugin_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// class MockBackgroundLocationPluginPlatform
//     with MockPlatformInterfaceMixin
//     implements BackgroundLocationPluginPlatform {

//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }

// void main() {
//   final BackgroundLocationPluginPlatform initialPlatform = BackgroundLocationPluginPlatform.instance;

//   test('$MethodChannelBackgroundLocationPlugin is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelBackgroundLocationPlugin>());
//   });

//   test('getPlatformVersion', () async {
//     BackgroundLocationPlugin backgroundLocationPlugin = BackgroundLocationPlugin();
//     MockBackgroundLocationPluginPlatform fakePlatform = MockBackgroundLocationPluginPlatform();
//     BackgroundLocationPluginPlatform.instance = fakePlatform;

//     expect(await backgroundLocationPlugin.getPlatformVersion(), '42');
//   });
// }
