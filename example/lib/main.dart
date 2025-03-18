import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:background_location_plugin/background_location_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // final _backgroundLocationPlugin = BackgroundLocationPlugin();
  String _verificationStatus = "Not started";
  bool _isVerifying = false;
  String _lastLocation = "No location data";
  bool _isInsideBuffer = false;
  double _timeRemainingSeconds = 0;
  double _timeSpentInBuffer = 0;
  double _timeNeededInBuffer = 0;
  late StreamSubscription _locationSubscription;
  late StreamSubscription _resultSubscription;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    // Check if verification was already running
    _checkVerificationStatus();

    _locationSubscription =
        BackgroundLocationPlugin.locationStream.listen((data) {
      print(data);
      setState(() {
        _lastLocation = "lat: ${data['latitude']}, lng: ${data['longitude']}";
        _isInsideBuffer = data['isInsideBuffer'] ?? false;
      });
    });

    _resultSubscription =
        BackgroundLocationPlugin.resultStream.listen((result) {
      setState(() {
        _verificationStatus = result;
        _isVerifying = false;
      });

      showDialog(
          context: context,
          builder: (context) => AlertDialog(
                title: Text('verification Result'),
                content: Text('Status: $result'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              ));
    });
  }

  void _checkVerificationStatus() async {
    final status = await BackgroundLocationPlugin.getStatus();
    if (status['isRunning'] == true) {
      setState(() {
        _isVerifying = true;
        _timeRemainingSeconds = status['timeRemaining'] ?? 0;
        _timeSpentInBuffer = status['timeSpentInBuffer'] ?? 0;
        _timeNeededInBuffer = status['timeNeededInBuffer'] ?? 0;
        _isInsideBuffer = status['isCurrentlyInBuffer'] ?? false;
        _verificationStatus = "Verification in progress";

        // Start timer to update remaining time
        _startStatusTimer();
      });
    }
  }

  void _startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (_isVerifying) {
        final status = await BackgroundLocationPlugin.getStatus();
        setState(() {
          _timeRemainingSeconds = status['timeRemaining'] ?? 0;
          _timeSpentInBuffer = status['timeSpentInBuffer'] ?? 0;
        });
      } else {
        _stopStatusTimer();
      }
    });
  }

  void _stopStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    _resultSubscription.cancel();
    super.dispose();
  }

  void _startVerification() async {
    await _requestPermissions();
    // Example parameters - in a real app, you would get these from user input or your backend
    final targetLat = 6.622644;
    final targetLng = 3.36055;
    final bufferRadius = 50.0; // 50 meters
    final verificationWindow = 120000.0; // 10 minutes in milliseconds
    final verificationThreshold = 60000.0; // 5 minutes in milliseconds

    final result = await BackgroundLocationPlugin.startService(
      targetLat: targetLat,
      targetLng: targetLng,
      bufferRadius: bufferRadius,
      verificationWindow: verificationWindow,
      verificationThreshold: verificationThreshold,
    );

    setState(() {
      _verificationStatus = "Started: $result";
      _isVerifying = true;
      _timeRemainingSeconds = verificationWindow / 1000;
      _timeSpentInBuffer = 0;
      _timeNeededInBuffer = verificationThreshold / 1000;

      // Start timer to update remaining time
      _startStatusTimer();
    });
  }

  void _stopVerification() async {
    final result = await BackgroundLocationPlugin.stopService();

    setState(() {
      _verificationStatus = "Stopped: $result";
      _isVerifying = false;
      _stopStatusTimer();
    });
  }

  Future<void> _requestPermissions() async {
    PermissionStatus status = await Permission.locationWhenInUse.request();

    if (status.isGranted) {
      // Ask for background location permission
      PermissionStatus bgStatus = await Permission.locationAlways.request();

      if (bgStatus.isGranted) {
        print("Background location permission granted.");
      } else {
        print("Background location permission denied.");
      }
    } else {
      print("Location permission denied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercentage = _isVerifying && _timeNeededInBuffer > 0
        ? (_timeSpentInBuffer / _timeNeededInBuffer).clamp(0.0, 1.0)
        : 0.0;

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification Status:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_verificationStatus),
              SizedBox(height: 16),
              if (_isVerifying) ...[
                Text('Time Remaining:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '${(_timeRemainingSeconds / 60).floor()}:${(_timeRemainingSeconds % 60).floor().toString().padLeft(2, '0')}'),
                SizedBox(height: 16),
                Text('Progress:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                LinearProgressIndicator(value: progressPercentage),
                Text(
                    '${(_timeSpentInBuffer / 60).floor()}:${(_timeSpentInBuffer % 60).floor().toString().padLeft(2, '0')} / '
                    '${(_timeNeededInBuffer / 60).floor()}:${(_timeNeededInBuffer % 60).floor().toString().padLeft(2, '0')}'),
                SizedBox(height: 16),
              ],
              Text('Current Location:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_lastLocation),
              SizedBox(height: 8),
              Row(
                children: [
                  Text('Inside Buffer Zone:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isInsideBuffer ? Colors.green : Colors.red,
                    ),
                  ),
                  if (_isInsideBuffer)
                    Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text("Time is being counted",
                          style: TextStyle(color: Colors.green)),
                    ),
                ],
              ),
              SizedBox(height: 24),
              Center(
                child: _isVerifying
                    ? ElevatedButton(
                        onPressed: _stopVerification,
                        child: Text('Stop Verification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _startVerification,
                        child: Text('Start Verification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
              ),
              if (Platform.isIOS) ...[
                SizedBox(height: 16),
                Text('⚠️ iOS Background Notice:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'Keep the app in the background rather than fully closing it for best results. '
                    'The app will use notifications to inform you of verification progress.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
