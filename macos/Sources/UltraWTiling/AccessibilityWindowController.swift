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

    func focusedWindow() -> ManagedWindow? {
        guard requestTrust(prompt: false) else {
            return nil
        }

        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedWindowAttribute as CFString,
            &value
        )
        guard result == .success, let element = value else {
            return nil
        }

        let window = element as! AXUIElement
        guard let axFrame = frame(of: window) else {
            return nil
        }

        return ManagedWindow(
            element: window,
            appKitFrame: CoordinateSpace.appKitFrame(fromAXFrame: axFrame)
        )
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
