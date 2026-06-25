import AppKit

@main
struct UltraWTilingApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppController()
        app.delegate = delegate
        app.run()
    }
}
