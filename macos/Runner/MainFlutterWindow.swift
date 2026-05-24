import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    let baseContentSize = NSSize(width: 1024, height: 720)
    let currentContentRect = self.contentRect(forFrameRect: windowFrame)
    let frameScale = max(
      1.0,
      min(
        currentContentRect.size.width / baseContentSize.width,
        currentContentRect.size.height / baseContentSize.height
      )
    )
    let scaledContentSize = NSSize(
      width: baseContentSize.width * frameScale,
      height: baseContentSize.height * frameScale
    )
    self.contentViewController = flutterViewController
    self.setContentSize(scaledContentSize)
    self.minSize = NSSize(width: 1024, height: 720)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
