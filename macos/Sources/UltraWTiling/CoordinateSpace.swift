import AppKit

enum CoordinateSpace {
    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    static func axFrame(fromAppKitFrame frame: CGRect) -> CGRect {
        let top = globalTop
        return CGRect(
            x: frame.minX,
            y: top - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func appKitFrame(fromAXFrame frame: CGRect) -> CGRect {
        let top = globalTop
        return CGRect(
            x: frame.minX,
            y: top - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    private static var globalTop: CGFloat {
        NSScreen.screens.map { $0.frame.maxY }.max() ?? NSScreen.main?.frame.maxY ?? 0
    }
}
