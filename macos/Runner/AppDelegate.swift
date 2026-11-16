import Cocoa
import FlutterMacOS

// Start the native macOS Flutter runner.
@main
class AppDelegate: FlutterAppDelegate {
// Exit when the last application window closes.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

// Allow secure restoration of the native window state.
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
