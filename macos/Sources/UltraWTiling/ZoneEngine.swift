import AppKit

struct ZoneSelection {
    let start: Int
    let span: Int
    var rows = 1
    var row = 0
    var rowSpan = 1
}

final class ZoneEngine {
    static let validCounts = 2...8
    static let maxRows = 6

    var count = 3

    func zoneIndex(at point: CGPoint, in frame: CGRect) -> Int {
        guard count > 0, frame.width > 0 else {
            return 0
        }

        let relativeX = min(max(point.x - frame.minX, 0), frame.width - 1)
        let rawIndex = Int(floor(relativeX / (frame.width / CGFloat(count))))
        return min(max(rawIndex, 0), count - 1)
    }

    // Row 0 is the top row; AppKit y grows upward.
    func rowIndex(at point: CGPoint, in frame: CGRect, rows: Int) -> Int {
        guard rows > 1, frame.height > 0 else {
            return 0
        }

        let fromTop = min(max(frame.maxY - point.y, 0), frame.height - 1)
        return clamp(Int(floor(fromTop / (frame.height / CGFloat(rows)))), lower: 0, upper: rows - 1)
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

        let rows = max(selection.rows, 1)
        let row = clamp(selection.row, lower: 0, upper: rows - 1)
        let rowSpan = clamp(selection.rowSpan, lower: 1, upper: rows - row)
        let top = visibleFrame.maxY - visibleFrame.height * CGFloat(row) / CGFloat(rows)
        let bottom = visibleFrame.maxY - visibleFrame.height * CGFloat(row + rowSpan) / CGFloat(rows)

        return CGRect(
            x: round(left),
            y: round(bottom),
            width: round(right) - round(left),
            height: round(top) - round(bottom)
        )
    }

    private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
        min(max(value, lower), upper)
    }
}
