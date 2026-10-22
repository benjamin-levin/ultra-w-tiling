import AppKit
import Carbon.HIToolbox

final class GestureController {
    private let zoneEngine: ZoneEngine
    private let accessibility: AccessibilityWindowController
    private let overlay: OverlayController
    private let notifier: NotificationController

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var drag: ActiveDrag?
    private(set) var isRunning = false

    init(
        zoneEngine: ZoneEngine,
        accessibility: AccessibilityWindowController,
        overlay: OverlayController,
        notifier: NotificationController
    ) {
        self.zoneEngine = zoneEngine
        self.accessibility = accessibility
        self.overlay = overlay
        self.notifier = notifier
    }

    func start() {
        stop()

        let mask =
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDragged.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            debugLog("event tap creation failed (listen access \(CGPreflightListenEventAccess()), AX trusted \(AXIsProcessTrusted()))")
            notifier.showMessage("Drag watcher needs Input Monitoring permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        debugLog("event tap started (enabled \(CGEvent.tapIsEnabled(tap: tap)), listen access \(CGPreflightListenEventAccess()), AX trusted \(AXIsProcessTrusted()))")
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isRunning = false
        drag = nil
        overlay.hide()
    }

    private var loggedEventTypes = Set<UInt32>()
    private var swallowedKeyUps = Set<Int>()
    // Row count persists across drags and launches.
    private var rows = min(max(UserDefaults.standard.integer(forKey: "rowCount"), 1), ZoneEngine.maxRows) {
        didSet { UserDefaults.standard.set(rows, forKey: "rowCount") }
    }

    // Returns true when the event should be swallowed.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Bool {
        if loggedEventTypes.insert(type.rawValue).inserted {
            debugLog("first event of type \(type.rawValue), flags \(String(event.flags.rawValue, radix: 16))")
        }
        switch type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged, .flagsChanged:
            updatePreview(flags: event.flags)
        case .leftMouseUp:
            handleMouseUp(event)
        case .keyDown, .keyUp:
            return handleKey(type: type, event: event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
        return false
    }

    // While the preview is showing, A adds a row to the target tile and Z
    // removes one. Those presses are swallowed so the app being dragged does
    // not also receive them.
    private func handleKey(type: CGEventType, event: CGEvent) -> Bool {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == kVK_ANSI_A || keyCode == kVK_ANSI_Z else {
            return false
        }

        if type == .keyUp {
            return swallowedKeyUps.remove(keyCode) != nil
        }

        guard var drag, event.flags.contains(.maskAlternate) else {
            return false
        }

        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            let delta = keyCode == kVK_ANSI_A ? 1 : -1
            rows = min(max(rows + delta, 1), ZoneEngine.maxRows)
            // Re-latch the span corner so it stays inside the new row grid.
            drag.spanStart = nil
            self.drag = drag
            updatePreview(flags: event.flags)
        }
        swallowedKeyUps.insert(keyCode)
        return true
    }

    // Every titlebar drag is tracked so Option can be pressed or released at any
    // point during the drag. The window only snaps if Option is held on release.
    private func handleMouseDown(_ event: CGEvent) {
        drag = nil
        overlay.hide()

        let point = mouseLocation
        guard let window = accessibility.window(at: point),
              window.appKitFrame.contains(point),
              isLikelyTitlebar(point: point, frame: window.appKitFrame) else {
            return
        }

        drag = ActiveDrag(window: window, startPoint: point, spanStart: nil)
        updatePreview(flags: event.flags)
    }

    private func updatePreview(flags: CGEventFlags) {
        guard var drag else {
            return
        }

        guard flags.contains(.maskAlternate),
              let target = currentTarget(flags: flags, drag: &drag) else {
            drag.spanStart = nil
            self.drag = drag
            overlay.hide()
            return
        }

        self.drag = drag
        overlay.show(on: target.screen, selection: target.selection)
    }

    private func handleMouseUp(_ event: CGEvent) {
        guard var drag else {
            return
        }

        self.drag = nil
        overlay.hide()

        let point = mouseLocation
        let distance = hypot(point.x - drag.startPoint.x, point.y - drag.startPoint.y)
        guard distance >= 8,
              event.flags.contains(.maskAlternate),
              let target = currentTarget(flags: event.flags, drag: &drag) else {
            return
        }

        let frame = zoneEngine.frame(for: target.selection, in: target.screen.visibleFrame)
        if !accessibility.setFrame(frame, for: drag.window) {
            notifier.showMessage("Could not resize this window")
        }
    }

    // Shift latches the span corner at the cell (column, row) under the pointer
    // when it is first pressed with Option; the selection is the rectangle from
    // that corner to the cell under the pointer. Releasing Shift returns to a
    // single cell.
    private func currentTarget(flags: CGEventFlags, drag: inout ActiveDrag) -> (screen: NSScreen, selection: ZoneSelection)? {
        let point = mouseLocation
        guard let screen = CoordinateSpace.screen(containing: point) else {
            return nil
        }

        let column = zoneEngine.zoneIndex(at: point, in: screen.visibleFrame)
        let row = zoneEngine.rowIndex(at: point, in: screen.visibleFrame, rows: rows)
        if flags.contains(.maskShift) {
            if drag.spanStart == nil {
                drag.spanStart = (column, row)
            }
        } else {
            drag.spanStart = nil
        }

        let start = drag.spanStart ?? (column, row)
        var selection = zoneEngine.selection(start: start.column, end: column, span: drag.spanStart != nil)
        selection.rows = rows
        selection.row = min(start.row, row)
        selection.rowSpan = abs(start.row - row) + 1
        return (screen, selection)
    }

    private func isLikelyTitlebar(point: CGPoint, frame: CGRect) -> Bool {
        let titlebarHeight: CGFloat = min(72, max(36, frame.height * 0.16))
        return point.y >= frame.maxY - titlebarHeight
    }

    private var mouseLocation: CGPoint {
        NSEvent.mouseLocation
    }
}

private struct ActiveDrag {
    let window: ManagedWindow
    let startPoint: CGPoint
    var spanStart: (column: Int, row: Int)?
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<GestureController>.fromOpaque(userInfo).takeUnretainedValue()
    if controller.handle(type: type, event: event) {
        return nil
    }
    return Unmanaged.passUnretained(event)
}
