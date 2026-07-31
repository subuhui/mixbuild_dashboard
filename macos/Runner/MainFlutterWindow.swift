import Cocoa
import FlutterMacOS
import UserNotifications

class MainFlutterWindow: NSWindow, UNUserNotificationCenterDelegate {
  override func awakeFromNib() {
    let isMcpMode = ProcessInfo.processInfo.arguments.contains("--mcp")
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
    configureBuildNotifications(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    if isMcpMode {
      self.orderOut(nil)
    }
  }

  private func configureBuildNotifications(messenger: FlutterBinaryMessenger) {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

    let channel = FlutterMethodChannel(
      name: "mixbuild_dashboard/build_notifications",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showBuildNotification" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let title = arguments["title"] as? String,
        let body = arguments["body"] as? String
      else {
        result(FlutterError(
          code: "invalid_arguments",
          message: "title and body are required",
          details: nil
        ))
        return
      }
      self?.showBuildNotification(title: title, body: body)
      result(nil)
    }
  }

  private func showBuildNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["source": "mixbuild_dashboard"]

    let request = UNNotificationRequest(
      identifier: "mixbuild-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    activateMainWindow()
    completionHandler()
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.alert, .sound])
  }

  private func activateMainWindow() {
    NSApp.activate(ignoringOtherApps: true)
    makeKeyAndOrderFront(nil)
  }
}
