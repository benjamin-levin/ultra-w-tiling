import AppKit

struct ZoneSelection {
    let start: Int
    let span: Int
}

final class ZoneEngine {
    static let validCounts = 2...8

    var count = 3

    func zoneIndex(at point: CGPoint, in frame: CGRect) -> Int {
        guard count > 0, frame.width > 0 else {
            return 0
        }

        let relativeX = min(max(point.x - frame.minX, 0), frame.width - 1)
        let rawIndex = Int(floor(relativeX / (frame.width / CGFloat(count))))
        return min(max(rawIndex, 0), count - 1)
    }

    func selection(start: Int, end: Int, span: Bool) -> ZoneSelection {
        if !span {
            return ZoneSelection(start: clamp(end, lower: 0, upper: count - 1), span: 1)
        }

        let first = clamp(min(start, end), lower: 0, upper: count - 1)
        let last = clamp(max(start, end), lower: 0, upper: count - 1)
        return ZoneSelection(start: first, span: last - first + 1)
    }

    func frame(for selection: ZoneSelection, in visibleFrame: CGRect) -> CGRect {
        let safeStart = clamp(selection.start, lower: 0, upper: count - 1)
        let safeSpan = clamp(selection.span, lower: 1, upper: count - safeStart)
        let left = visibleFrame.minX + visibleFrame.width * CGFloat(safeStart) / CGFloat(count)
        let right = visibleFrame.minX + visibleFrame.width * CGFloat(safeStart + safeSpan) / CGFloat(count)

        return CGRect(
            x: round(left),
            y: visibleFrame.minY,
            width: round(right) - round(left),
            height: visibleFrame.height
        )
    }

    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
