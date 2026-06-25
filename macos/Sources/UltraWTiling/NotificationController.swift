import Foundation

final class NotificationController {
    func showModeChanged(count: Int) {
        showMessage("\(count) column drag grid")
    }

    func showMessage(_ message: String) {
        let notification = NSUserNotification()
        notification.title = "Ultra-W Tiling"
        notification.informativeText = message
        NSUserNotificationCenter.default.deliver(notification)
    }
}
