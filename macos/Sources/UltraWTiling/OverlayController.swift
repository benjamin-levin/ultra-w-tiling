import AppKit

final class OverlayController {
    private let zoneEngine: ZoneEngine
    private var panel: NSPanel?
    private var overlayView: OverlayView?

    init(zoneEngine: ZoneEngine) {
        self.zoneEngine = zoneEngine
    }

    func show(on screen: NSScreen, selection: ZoneSelection) {
        let view: OverlayView
        if let panel, let overlayView, panel.frame == screen.visibleFrame {
            view = overlayView
        } else {
            hide()
            let panel = NSPanel(
                contentRect: screen.visibleFrame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

            view = OverlayView(frame: CGRect(origin: .zero, size: screen.visibleFrame.size))
            panel.contentView = view
            self.panel = panel
            self.overlayView = view
        }

        view.count = zoneEngine.count
        view.selection = selection
        view.needsDisplay = true
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
    }
}

private final class OverlayView: NSView {
    var count = 3
    var selection = ZoneSelection(start: 0, span: 1)

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard count > 0 else {
            return
        }

        let segmentWidth = bounds.width / CGFloat(count)
        let base = NSColor.systemGray.withAlphaComponent(0.22)
        let selected = NSColor.controlAccentColor.withAlphaComponent(0.34)
        let stroke = NSColor.white.withAlphaComponent(0.68)

        for index in 0..<count {
            let rect = NSRect(
                x: CGFloat(index) * segmentWidth,
                y: 0,
                width: segmentWidth,
                height: bounds.height
            ).insetBy(dx: 2, dy: 2)

            let isSelected = index >= selection.start && index < selection.start + selection.span
            if !isSelected || selection.rows == 1 {
                (isSelected ? selected : base).setFill()
                NSBezierPath(rect: rect).fill()
            }

            stroke.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            path.stroke()
        }

        guard selection.rows > 1 else {
            return
        }

        // Split the selected columns into rows and highlight the target row.
        let rowHeight = bounds.height / CGFloat(selection.rows)
        let left = CGFloat(selection.start) * segmentWidth
        let width = CGFloat(selection.span) * segmentWidth
        for row in 0..<selection.rows {
            let rect = NSRect(
                x: left,
                y: CGFloat(row) * rowHeight,
                width: width,
                height: rowHeight
            ).insetBy(dx: 2, dy: 2)

            let isSelected = row >= selection.row && row < selection.row + selection.rowSpan
            (isSelected ? selected : base).setFill()
            NSBezierPath(rect: rect).fill()

            stroke.setStroke()
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 1
            path.stroke()
        }
    }
}
