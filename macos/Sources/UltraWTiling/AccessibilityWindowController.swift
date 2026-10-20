import AppKit
import ApplicationServices

struct ManagedWindow {
    let element: AXUIElement
    let appKitFrame: CGRect
}

final class AccessibilityWindowController {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestTrust(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func window(at appKitPoint: CGPoint) -> ManagedWindow? {
        guard isTrusted else {
            return nil
        }

        let axPoint = CoordinateSpace.axPoint(fromAppKitPoint: appKitPoint)
        guard let window = windowFromWindowList(at: axPoint) ?? windowFromHitTest(at: axPoint) else {
            debugLog("no window under pointer at \(axPoint)")
            return nil
        }

        guard let axFrame = frame(of: window) else {
            debugLog("window under pointer has no frame")
            return nil
        }

        return ManagedWindow(
            element: window,
            appKitFrame: CoordinateSpace.appKitFrame(fromAXFrame: axFrame)
        )
    }

    // Finds the frontmost normal window under the point from the window server,
    // then matches it to one of its app's Accessibility windows by frame. Works
    // for apps that do not implement Accessibility hit-testing (e.g. Telegram).
    private func windowFromWindowList(at axPoint: CGPoint) -> AXUIElement? {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        for entry in info {
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.contains(axPoint) else {
                continue
            }

            let app = AXUIElementCreateApplication(pid)
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
                  let windows = value as? [AXUIElement] else {
                debugLog("could not list windows for pid \(pid)")
                return nil
            }

            let match = windows
                .compactMap { window in frame(of: window).map { (window, $0) } }
                .min { distance($0.1, bounds) < distance($1.1, bounds) }
            if let match, distance(match.1, bounds) < 4 {
                return match.0
            }
            debugLog("no Accessibility window matches \(bounds) for pid \(pid)")
            return nil
        }
        return nil
    }

    private func windowFromHitTest(at axPoint: CGPoint) -> AXUIElement? {
        var hit: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            AXUIElementCreateSystemWide(),
            Float(axPoint.x),
            Float(axPoint.y),
            &hit
        )
        guard result == .success, let hit else {
            debugLog("hit-test failed (AX error \(result.rawValue))")
            return nil
        }
        return containingWindow(of: hit)
    }

    private func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        abs(a.minX - b.minX) + abs(a.minY - b.minY) + abs(a.width - b.width) + abs(a.height - b.height)
    }

    private func containingWindow(of element: AXUIElement) -> AXUIElement? {
        if stringAttribute(kAXRoleAttribute, of: element) == kAXWindowRole as String {
            return element
        }

        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
           let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
            return (value as! AXUIElement)
        }

        var current = element
        for _ in 0..<12 {
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else {
                return nil
            }
            current = parent as! AXUIElement
            if stringAttribute(kAXRoleAttribute, of: current) == kAXWindowRole as String {
                return current
            }
        }
        return nil
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    func setFrame(_ appKitFrame: CGRect, for window: ManagedWindow) -> Bool {
        let axFrame = CoordinateSpace.axFrame(fromAppKitFrame: appKitFrame)
        var position = axFrame.origin
        var size = axFrame.size

        guard
            let positionValue = AXValueCreate(.cgPoint, &position),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }

        let positionResult = AXUIElementSetAttributeValue(
            window.element,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window.element,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        return positionResult == .success && sizeResult == .success
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute, of: window),
              let size = sizeAttribute(kAXSizeAttribute, of: window) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(_ attribute: String, of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard result == .success, let axValue = value else {
            return nil
        }

        var point = CGPoint.zero
        guard CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private func sizeAttribute(_ attribute: String, of window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        guard result == .success, let axValue = value else {
            return nil
        }

        var size = CGSize.zero
        guard CFGetTypeID(axValue) == AXValueGetTypeID(),
              AXValueGetValue(axValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return size
    }
}
