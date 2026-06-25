import AppKit

final class AppController: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let zoneEngine = ZoneEngine()
    private let accessibility = AccessibilityWindowController()
    private lazy var overlay = OverlayController(zoneEngine: zoneEngine)
    private lazy var hotkeys = HotkeyController()
    private lazy var gestures = GestureController(
        zoneEngine: zoneEngine,
        accessibility: accessibility,
        overlay: overlay,
        notifier: notifier
    )
    private let notifier = NotificationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        zoneEngine.count = UserDefaults.standard.integer(forKey: "zoneCount")
        if !ZoneEngine.validCounts.contains(zoneEngine.count) {
            zoneEngine.count = 3
        }

        configureStatusItem()
        registerHotkeys()
        _ = accessibility.requestTrust(prompt: true)
        gestures.start()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "UW \(zoneEngine.count)"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        for count in ZoneEngine.validCounts {
            let item = NSMenuItem(
                title: "\(count) Columns",
                action: #selector(selectMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = count
            item.state = count == zoneEngine.count ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let permissionItem = NSMenuItem(
            title: "Request Accessibility Permission",
            action: #selector(requestAccessibilityPermission),
            keyEquivalent: ""
        )
        permissionItem.target = self
        menu.addItem(permissionItem)

        let retapItem = NSMenuItem(
            title: "Restart Drag Watcher",
            action: #selector(restartDragWatcher),
            keyEquivalent: ""
        )
        retapItem.target = self
        menu.addItem(retapItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Ultra-W Tiling",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func registerHotkeys() {
        for count in ZoneEngine.validCounts {
            hotkeys.registerModeHotkey(count: count) { [weak self] in
                self?.setMode(count)
            }
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        setMode(sender.tag)
    }

    private func setMode(_ count: Int) {
        guard ZoneEngine.validCounts.contains(count) else {
            return
        }

        zoneEngine.count = count
        UserDefaults.standard.set(count, forKey: "zoneCount")
        statusItem.button?.title = "UW \(count)"
        rebuildMenu()
        notifier.showModeChanged(count: count)
    }

    @objc private func requestAccessibilityPermission() {
        _ = accessibility.requestTrust(prompt: true)
    }

    @objc private func restartDragWatcher() {
        gestures.stop()
        gestures.start()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
