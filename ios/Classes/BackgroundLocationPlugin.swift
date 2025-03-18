import Flutter
import UIKit
import CoreLocation
import UserNotifications

public class BackgroundLocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, UNUserNotificationCenterDelegate {
  private var locationManager = CLLocationManager()
  private var methodChannel: FlutterMethodChannel?

  // Keys for UserDefaults to persist data
  private let targetLatKey = "com.example.background_location_plugin.targetLat"
  private let targetLngKey = "com.example.background_location_plugin.targetLng"
  private let bufferRadiusKey = "com.example.background_location_plugin.bufferRadius"
  private let verificationWindowKey = "com.example.background_location_plugin.verificationWindow"
  private let verificationThresholdKey = "com.example.background_location_plugin.verificationThreshold"
  private let totalTimeInsideKey = "com.example.background_location_plugin.totalTimeInside"
  private let lastEntryTimeKey = "com.example.background_location_plugin.lastEntryTime"
  private let verificationStartTimeKey = "com.example.background_location_plugin.verificationStartTime"
  private let isServiceRunningKey = "com.example.background_location_plugin.isServiceRunning"
  private let isVerifiedKey = "com.example.background_location_plugin.isVerified"
  
  // Verification parameters
  private var targetLatitude: Double = 6.622544
  private var targetLongitude: Double = 3.36055
  private var bufferRadius: Double = 50.0  // in meters
  private var verificationWindow: Double = 120000.0  // 10 minutes in milliseconds
  private var verificationThreshold: Double = 60000.0  // 5 minutes in milliseconds
  
  // Tracking variables
  private var totalTimeInside: TimeInterval = 0.0
  private var lastEntryTime: Date?
  private var verificationStartTime: Date?
  private var verificationTimer: Timer?
  private var statusUpdateTimer: Timer?
  private var isServiceRunning = false
  private var isVerified = false
  private var notificationPermissionGranted = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "background_location_plugin", binaryMessenger: registrar.messenger())
    let instance = BackgroundLocationPlugin()
    instance.methodChannel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Check if we need to restore location tracking after app restart
    instance.restoreStateIfNeeded()
  }

  override init() {
    super.init()
    setupLocationManager()
    setupNotifications()
  }
  
  private func setupLocationManager() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.distanceFilter = 5  // Update if moved more than 5 meters
    locationManager.showsBackgroundLocationIndicator = true
    locationManager.activityType = .other
    
    // This is critical for background monitoring
    if #available(iOS 11.0, *) {
      locationManager.setMinimumDisplacement(10) // Minimum movement needed
    }
  }
  
  private func setupNotifications() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
      self.notificationPermissionGranted = granted
      NSLog("BackgroundLocationPlugin: Notification permission granted: \(granted)")
      if let error = error {
        NSLog("BackgroundLocationPlugin: Notification permission error: \(error.localizedDescription)")
      }
    }
  }
  
  // This delegate method is important for showing notifications when app is in foreground
  public func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                    willPresent notification: UNNotification, 
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.alert, .sound])
  }
  
  private func restoreStateIfNeeded() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: isServiceRunningKey) {
      // Restore state
      targetLatitude = defaults.double(forKey: targetLatKey)
      targetLongitude = defaults.double(forKey: targetLngKey)
      bufferRadius = defaults.double(forKey: bufferRadiusKey)
      verificationWindow = defaults.double(forKey: verificationWindowKey)
      verificationThreshold = defaults.double(forKey: verificationThresholdKey)
      totalTimeInside = defaults.double(forKey: totalTimeInsideKey)
      isVerified = defaults.bool(forKey: isVerifiedKey)

      // Log the totalTimeInside value to iOS console
      NSLog("BackgroundLocationPlugin: RESTORED totalTimeInside: \(totalTimeInside)s")
      print("BackgroundLocationPlugin: RESTORED totalTimeInside: \(totalTimeInside)s")
      
      // Log to Flutter side via methodChannel
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.methodChannel?.invokeMethod("logMessage", arguments: [
          "message": "RESTORED totalTimeInside: \(self.totalTimeInside)s",
          "level": "info"
        ])
      }

      if let entryTimeStamp = defaults.object(forKey: lastEntryTimeKey) as? Date {
        lastEntryTime = entryTimeStamp
        NSLog("BackgroundLocationPlugin: Restored lastEntryTime: \(lastEntryTime!)")
      }
      
      if let startTimeStamp = defaults.object(forKey: verificationStartTimeKey) as? Date {
        verificationStartTime = startTimeStamp
        
        // Don't restart verification if already verified
        if isVerified {
          NSLog("BackgroundLocationPlugin: Restored already verified state")
          
          // Log to Flutter side via methodChannel
          DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("logMessage", arguments: [
              "message": "Restored already verified state",
              "level": "info"
            ])
          }
          return
        }
        
        // Calculate remaining time in verification window
        let elapsedTime = Date().timeIntervalSince(startTimeStamp) * 1000
        let remainingTime = max(0, verificationWindow - elapsedTime)
        
        // If there's still time remaining, restart the timer
        if remainingTime > 0 {
          isServiceRunning = true
          locationManager.startUpdatingLocation()
          
          // Restarts verification timer with remaining time
          verificationTimer = Timer.scheduledTimer(withTimeInterval: remainingTime / 1000.0, repeats: false) { [weak self] _ in
            self?.checkVerificationStatus()
          }
          
          // Start the status update timer
          startStatusUpdateTimer()
          
          let message = "Restored location service with \(remainingTime / 1000.0)s remaining and totalTimeInside: \(totalTimeInside)s"
          NSLog("BackgroundLocationPlugin: \(message)")
          
          // Log to Flutter side via methodChannel
          DispatchQueue.main.async { [weak self] in
            self?.methodChannel?.invokeMethod("logMessage", arguments: [
              "message": message,
              "level": "info"
            ])
          }
          
          showLocalNotification(title: "Location Verification", body: "Verification resumed after app restart")
        } else {
          // Verification window has expired
          checkVerificationStatus()
        }
      }
    }
  }

  private func saveState() {
    let defaults = UserDefaults.standard
    defaults.set(targetLatitude, forKey: targetLatKey)
    defaults.set(targetLongitude, forKey: targetLngKey)
    defaults.set(bufferRadius, forKey: bufferRadiusKey)
    defaults.set(verificationWindow, forKey: verificationWindowKey)
    defaults.set(verificationThreshold, forKey: verificationThresholdKey)
    defaults.set(totalTimeInside, forKey: totalTimeInsideKey)
    defaults.set(lastEntryTime, forKey: lastEntryTimeKey)
    defaults.set(verificationStartTime, forKey: verificationStartTimeKey)
    defaults.set(isServiceRunning, forKey: isServiceRunningKey)
    defaults.set(isVerified, forKey: isVerifiedKey)
    
    // Force UserDefaults to save immediately
    defaults.synchronize()
    
    // Log totalTimeInside when saving state
    NSLog("BackgroundLocationPlugin: SAVED totalTimeInside: \(totalTimeInside)s")
    
    // Log to Flutter side via methodChannel
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.methodChannel?.invokeMethod("logMessage", arguments: [
        "message": "SAVED totalTimeInside: \(self.totalTimeInside)s",
        "level": "info"
      ])
    }
  }
  
  private func clearState() {
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: targetLatKey)
    defaults.removeObject(forKey: targetLngKey)
    defaults.removeObject(forKey: bufferRadiusKey)
    defaults.removeObject(forKey: verificationWindowKey)
    defaults.removeObject(forKey: verificationThresholdKey)
    defaults.removeObject(forKey: totalTimeInsideKey)
    defaults.removeObject(forKey: lastEntryTimeKey)
    defaults.removeObject(forKey: verificationStartTimeKey)
    defaults.removeObject(forKey: isServiceRunningKey)
    defaults.removeObject(forKey: isVerifiedKey)
    
    // Force UserDefaults to save immediately
    defaults.synchronize()
    
    NSLog("BackgroundLocationPlugin: Cleared all state")
    
    // Log to Flutter side via methodChannel
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("logMessage", arguments: [
        "message": "Cleared all state",
        "level": "info"
      ])
    }
  }
  
  private func startStatusUpdateTimer() {
    // Cancel any existing timer
    statusUpdateTimer?.invalidate()
    
    // Create a new timer that fires every second
    statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
      self?.sendStatusUpdate()
    }
  }
  
  private func stopStatusUpdateTimer() {
    statusUpdateTimer?.invalidate()
    statusUpdateTimer = nil
  }
  
  private func sendStatusUpdate() {
    guard let startTime = verificationStartTime, isServiceRunning else { return }
    
    // Calculate current time inside buffer, including current session if inside buffer
    var currentTotalTimeInside = totalTimeInside
    if let entryTime = lastEntryTime {
      currentTotalTimeInside += Date().timeIntervalSince(entryTime)
    }
    
    // Calculate remaining time in verification window
    let elapsedMillis = Date().timeIntervalSince(startTime) * 1000
    let remainingTime = max(0, verificationWindow - elapsedMillis) / 1000.0
    
    // Send status update to Flutter
    let statusUpdate: [String: Any] = [
      "isRunning": isServiceRunning,
      "timeRemaining": remainingTime,
      "timeSpentInBuffer": currentTotalTimeInside,
      "timeNeededInBuffer": verificationThreshold / 1000.0,
      "isCurrentlyInBuffer": lastEntryTime != nil,
      "isVerified": isVerified
    ]
    
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("statusUpdate", arguments: statusUpdate)
    }
    
    // Check if verification threshold is met
    if currentTotalTimeInside >= (verificationThreshold / 1000.0) && !isVerified {
      isVerified = true
      saveState()
      sendResult(status: "Verified")
    }
  }
  
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  if call.method == "startService" {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments must be a dictionary", details: nil))
      return
    }

    // Ensure all required parameters are provided
    guard let targetLat = args["targetLat"] as? Double,
          let targetLng = args["targetLng"] as? Double,
          let radius = args["bufferRadius"] as? Double,
          let window = args["verificationWindow"] as? Double,
          let threshold = args["verificationThreshold"] as? Double else {
      result(FlutterError(
        code: "MISSING_PARAMETERS",
        message: "Required parameters missing or have invalid types",
        details: "All parameters (targetLat, targetLng, bufferRadius, verificationWindow, verificationThreshold) must be provided as Double values"
      ))
      return
    }

    // Assign new values
    targetLatitude = targetLat
    targetLongitude = targetLng
    bufferRadius = radius
    verificationWindow = window
    verificationThreshold = threshold

    let defaults = UserDefaults.standard
    if let savedVerificationStartTime = defaults.object(forKey: verificationStartTimeKey) as? Date {
      // There's an existing session; restore state instead of resetting
      totalTimeInside = defaults.double(forKey: totalTimeInsideKey)
      lastEntryTime = defaults.object(forKey: lastEntryTimeKey) as? Date
      verificationStartTime = savedVerificationStartTime
      isVerified = defaults.bool(forKey: isVerifiedKey)

      NSLog("BackgroundLocationPlugin: Resuming session with totalTimeInside: \(totalTimeInside)s")
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.methodChannel?.invokeMethod("logMessage", arguments: [
          "message": "Resuming session with totalTimeInside: \(self.totalTimeInside)s",
          "level": "info"
        ])
      }
    } else {
      // No saved session, so initialize a new one
      totalTimeInside = 0.0
      lastEntryTime = nil
      verificationStartTime = Date()
      isVerified = false

      NSLog("BackgroundLocationPlugin: Starting new session, resetting totalTimeInside")
      DispatchQueue.main.async { [weak self] in
        self?.methodChannel?.invokeMethod("logMessage", arguments: [
          "message": "Starting new session, resetting totalTimeInside to 0.0s",
          "level": "info"
        ])
      }
    }

    isServiceRunning = true

    // Request location permissions and start tracking
    requestLocationPermissions()

    // Set up the verification timer using the remaining window if restoring a session;
    // otherwise, use the full window.
    verificationTimer?.invalidate()
    var timerInterval = verificationWindow / 1000.0
    if let savedStartTime = verificationStartTime {
      let elapsedTime = Date().timeIntervalSince(savedStartTime) * 1000
      timerInterval = max(0, (verificationWindow - elapsedTime) / 1000.0)
    }
    verificationTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) { [weak self] _ in
      self?.checkVerificationStatus()
    }

    startStatusUpdateTimer()
    saveState()

    NSLog("BackgroundLocationPlugin: Started location service with target (\(targetLatitude), \(targetLongitude)), radius: \(bufferRadius)m")
    result("iOS Service Started")
    
  } else if call.method == "stopService" {
    stopService()
    result("iOS Service Stopped")
  } else if call.method == "getVerificationStatus" {
    // Calculate current time inside buffer, including current session if inside buffer
    var currentTotalTimeInside = totalTimeInside
    if let entryTime = lastEntryTime {
      currentTotalTimeInside += Date().timeIntervalSince(entryTime)
    }
    
    let timeRemaining = getTimeRemaining()
    let status: [String: Any] = [
      "isRunning": isServiceRunning,
      "timeRemaining": timeRemaining,
      "timeSpentInBuffer": currentTotalTimeInside,
      "timeNeededInBuffer": verificationThreshold / 1000.0,
      "isCurrentlyInBuffer": lastEntryTime != nil,
      "isVerified": isVerified
    ]
    
    result(status)
  } else if call.method == "checkTotalTimeInsideValue" {
    result(["totalTimeInside": totalTimeInside])
  } else {
    result(FlutterMethodNotImplemented)
  }
}

  private func getTimeRemaining() -> Double {
    guard let startTime = verificationStartTime else { return 0 }
    let elapsedMillis = Date().timeIntervalSince(startTime) * 1000
    return max(0, verificationWindow - elapsedMillis) / 1000.0
  }

  private func stopService() {
    locationManager.stopUpdatingLocation()
    verificationTimer?.invalidate()
    verificationTimer = nil
    stopStatusUpdateTimer()
    isServiceRunning = false
    clearState()
    NSLog("BackgroundLocationPlugin: Stopped location service")
  }
  
  private func checkVerificationStatus() {
    // If still inside buffer when timer expires, add elapsed time
    if let entryTime = lastEntryTime {
      let additionalTime = Date().timeIntervalSince(entryTime)
      totalTimeInside += additionalTime
      lastEntryTime = nil
      
      NSLog("BackgroundLocationPlugin: Adding \(additionalTime)s to totalTimeInside, new total: \(totalTimeInside)s")
      
      // Log to Flutter side via methodChannel
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.methodChannel?.invokeMethod("logMessage", arguments: [
          "message": "Adding \(additionalTime)s to totalTimeInside, new total: \(self.totalTimeInside)s",
          "level": "info"
        ])
      }
      
      // Save updated state before checking verification status
      saveState()
    }
    
    // Check if threshold has been met
    if totalTimeInside >= (verificationThreshold / 1000.0) {
      isVerified = true
      saveState()
      sendResult(status: "Verified")
    } else {
      sendResult(status: "Failed")
    }
  }

  private func sendResult(status: String) {
    NSLog("BackgroundLocationPlugin: Verification result - \(status) with totalTimeInside: \(totalTimeInside)s")
    
    // Log to Flutter side via methodChannel
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.methodChannel?.invokeMethod("logMessage", arguments: [
        "message": "Verification result - \(status) with totalTimeInside: \(self.totalTimeInside)s",
        "level": "info"
      ])
    }

    // Send local notification with result
    showLocalNotification(title: "Verification Complete", body: "Result: \(status)")
    
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("verificationResult", arguments: ["status": status])
      
      // Only stop service if verification failed or window expired
      if status == "Failed" {
        self?.stopService()
      } else {
        // For successful verification, we'll keep the service running
        // but stop the verification window timer
        self?.verificationTimer?.invalidate()
        self?.verificationTimer = nil
      }
    }
  }
  
  private func isInsideBuffer(location: CLLocation) -> Bool {
    let targetLocation = CLLocation(latitude: targetLatitude, longitude: targetLongitude)
    let distance = location.distance(from: targetLocation)
    return distance <= bufferRadius
  }

  private func requestLocationPermissions() {
    let authorizationStatus: CLAuthorizationStatus
    
    if #available(iOS 14.0, *) {
      authorizationStatus = locationManager.authorizationStatus
    } else {
      authorizationStatus = CLLocationManager.authorizationStatus()
    }
    
    if authorizationStatus == .notDetermined {
      locationManager.requestWhenInUseAuthorization()  // First request "When In Use"
    } else if authorizationStatus == .authorizedWhenInUse {
      locationManager.requestAlwaysAuthorization()  // If granted, escalate to "Always"
    }
    
    locationManager.startUpdatingLocation()
  }

  public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard isServiceRunning, let location = locations.last else { return }
    
    let isInside = isInsideBuffer(location: location)
    NSLog("BackgroundLocationPlugin: Location update - lat: \(location.coordinate.latitude), lng: \(location.coordinate.longitude), inside buffer: \(isInside)")
    
    // Send location update to Flutter
    let locationData: [String: Any] = [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "isInsideBuffer": isInside,
      "distanceToTarget": location.distance(from: CLLocation(latitude: targetLatitude, longitude: targetLongitude)),
      "timestamp": Date().timeIntervalSince1970 * 1000
    ]
    
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("locationUpdate", arguments: locationData)
    }
    
    // Track time inside buffer
    if isInside {
      if lastEntryTime == nil {
        lastEntryTime = Date()
        NSLog("BackgroundLocationPlugin: Entered buffer zone, current totalTimeInside: \(totalTimeInside)s")
        
        // Log to Flutter side via methodChannel
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.methodChannel?.invokeMethod("logMessage", arguments: [
            "message": "Entered buffer zone, current totalTimeInside: \(self.totalTimeInside)s",
            "level": "info"
          ])
        }
        
        showLocalNotification(title: "Location Update", body: "You've entered the target area")
        
        // Save state when entering buffer
        saveState()
      }
    } else {
      if let entryTime = lastEntryTime {
        let additionalTime = Date().timeIntervalSince(entryTime)
        totalTimeInside += additionalTime
        lastEntryTime = nil
        
        NSLog("BackgroundLocationPlugin: Left buffer zone. Added \(additionalTime)s, total time inside now: \(totalTimeInside)s")
        
        // Log to Flutter side via methodChannel
        DispatchQueue.main.async { [weak self] in
          guard let self = self else { return }
          self.methodChannel?.invokeMethod("logMessage", arguments: [
            "message": "Left buffer zone. Added \(additionalTime)s, total time inside now: \(self.totalTimeInside)s",
            "level": "info"
          ])
        }
        
        // Save updated state immediately after updating totalTimeInside
        saveState()
        
        showLocalNotification(title: "Location Update", body: "You've left the target area")
      }
    }
  }
  
  private func showLocalNotification(title: String, body: String) {
    if !notificationPermissionGranted {
      NSLog("BackgroundLocationPlugin: Notification not shown - permission not granted")
      return
    }
    
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = UNNotificationSound.default
    
    // Create a unique identifier for each notification
    let identifier = UUID().uuidString
    
    // Create a request with the content and no trigger (immediate delivery)
    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    
    // Add the request to the notification center
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        NSLog("BackgroundLocationPlugin: Error showing notification: \(error.localizedDescription)")
      } else {
        NSLog("BackgroundLocationPlugin: Notification scheduled successfully: \(title)")
      }
    }
  }
  
  public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    var statusString = "unknown"
    switch status {
    case .authorizedAlways:
      statusString = "authorizedAlways"
    case .authorizedWhenInUse:
      statusString = "authorizedWhenInUse"
    case .denied:
      statusString = "denied"
    case .restricted:
      statusString = "restricted"
    case .notDetermined:
      statusString = "notDetermined"
    @unknown default:
      statusString = "unknown"
    }
    
    NSLog("BackgroundLocationPlugin: Authorization status changed to \(statusString)")
    
    // Send authorization status back to Flutter
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("authorizationStatusChanged", arguments: statusString)
    }

    // If permission denied, send failure result
    if status == .denied || status == .restricted {
      sendResult(status: "Failed")
    }
  }
  
  public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    NSLog("BackgroundLocationPlugin: Location manager failed with error: \(error.localizedDescription)")
    
    // Send error back to Flutter
    DispatchQueue.main.async { [weak self] in
      self?.methodChannel?.invokeMethod("locationError", arguments: error.localizedDescription)
    }
  }
}

@available(iOS 11.0, *)
extension CLLocationManager {
    func setMinimumDisplacement(_ meters: Double) {
        // This is a workaround - there's no direct equivalent in iOS to Android's 
        // .setSmallestDisplacement(), but setting distanceFilter achieves similar results
        self.distanceFilter = meters
    }
}