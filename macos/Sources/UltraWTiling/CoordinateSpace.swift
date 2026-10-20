import AppKit

enum CoordinateSpace {
    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    static func axPoint(fromAppKitPoint point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryTop - point.y)
    }

    static func axFrame(fromAppKitFrame frame: CGRect) -> CGRect {
        let top = primaryTop
        return CGRect(
            x: frame.minX,
            y: top - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func appKitFrame(fromAXFrame frame: CGRect) -> CGRect {
        let top = primaryTop
        return CGRect(
            x: frame.minX,
            y: top - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    // Accessibility coordinates start at the top-left of the primary display
    // (screens[0]), not the topmost display.
    private static var primaryTop: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
    }
}
