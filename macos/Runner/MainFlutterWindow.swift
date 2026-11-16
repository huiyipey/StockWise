import Cocoa
import FlutterMacOS

// Host the Flutter view inside the macOS application window.
class MainFlutterWindow: NSWindow {
// Create the Flutter view when the native window loads.
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

// Connect the generated native plugin registrations.
    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
