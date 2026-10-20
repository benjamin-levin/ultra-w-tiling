import os

private let logger = Logger(subsystem: "org.powerhouse.UltraWTiling", category: "gesture")

func debugLog(_ message: String) {
    logger.notice("\(message, privacy: .public)")
}
