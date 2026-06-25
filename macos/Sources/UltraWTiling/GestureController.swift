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
            CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            notifier.showMessage("Drag watcher needs Input Monitoring permission")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
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
        drag = nil
        overlay.hide()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp(event)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
        default:
            break
        }
    }

    private func handleMouseDown(_ event: CGEvent) {
        let flags = event.flags
        guard flags.contains(.maskShift),
              let window = accessibility.focusedWindow(),
              let screen = CoordinateSpace.screen(containing: mouseLocation) else {
            return
        }

        let point = mouseLocation
        guard window.appKitFrame.contains(point), isLikelyTitlebar(point: point, frame: window.appKitFrame) else {
            return
        }

        let span = flags.contains(.maskControl) || flags.contains(.maskAlphaShift)
        let start = zoneEngine.zoneIndex(at: point, in: screen.visibleFrame)
        drag = ActiveDrag(
            window: window,
            screen: screen,
            startPoint: point,
            startZone: start,
            span: span
        )

        let selection = zoneEngine.selection(start: start, end: start, span: span)
        overlay.show(on: screen, selection: selection)
    }

    private func handleMouseDragged(_ event: CGEvent) {
        guard var drag else {
            return
        }

        let flags = event.flags
        drag.span = drag.span || flags.contains(.maskControl) || flags.contains(.maskAlphaShift)
        self.drag = drag

        let point = mouseLocation
        let end = zoneEngine.zoneIndex(at: point, in: drag.screen.visibleFrame)
        let selection = zoneEngine.selection(start: drag.startZone, end: end, span: drag.span)
        overlay.show(on: drag.screen, selection: selection)
    }

    private func handleMouseUp(_ event: CGEvent) {
        guard let drag else {
            return
        }

        self.drag = nil
        overlay.hide()

        let point = mouseLocation
        let distance = hypot(point.x - drag.startPoint.x, point.y - drag.startPoint.y)
        guard distance >= 8 else {
            return
        }

        let end = zoneEngine.zoneIndex(at: point, in: drag.screen.visibleFrame)
        let selection = zoneEngine.selection(start: drag.startZone, end: end, span: drag.span)
        let frame = zoneEngine.frame(for: selection, in: drag.screen.visibleFrame)
        if !accessibility.setFrame(frame, for: drag.window) {
            notifier.showMessage("Could not resize this window")
        }
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
    let screen: NSScreen
    let startPoint: CGPoint
    let startZone: Int
    var span: Bool
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let controller = Unmanaged<GestureController>.fromOpaque(userInfo).takeUnretainedValue()
    controller.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
