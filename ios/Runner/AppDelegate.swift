import Flutter
import UIKit

// Start the iOS runner with the Flutter implicit engine.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
// Pass the iOS launch event to Flutter.
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

// Register native plugins when the Flutter engine is ready.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
