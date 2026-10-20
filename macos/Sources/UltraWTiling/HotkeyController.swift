import AppKit
import Carbon

final class HotkeyController {
    private var handlers: [UInt32: () -> Void] = [:]
    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var nextID: UInt32 = 1

    init() {
        installHandler()
    }

    deinit {
        for hotkeyRef in hotkeyRefs {
            if let hotkeyRef {
                UnregisterEventHotKey(hotkeyRef)
            }
        }
    }

    func registerModeHotkey(count: Int, handler: @escaping () -> Void) {
        guard let keyCode = Self.keyCode(forDigit: count) else {
            return
        }

        let id = nextID
        nextID += 1
        handlers[id] = handler

        var hotkeyID = EventHotKeyID(signature: Self.signature, id: id)
        var hotkeyRef: EventHotKeyRef?
        let modifiers = UInt32(cmdKey | optionKey)
        let result = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if result == noErr {
            hotkeyRefs.append(hotkeyRef)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            refcon,
            nil
        )
    }

    fileprivate func handle(event: EventRef?) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        let result = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard result == noErr else {
            return result
        }

        handlers[hotkeyID.id]?()
        return noErr
    }

    private static func keyCode(forDigit digit: Int) -> Int? {
        switch digit {
        case 2: return kVK_ANSI_2
        case 3: return kVK_ANSI_3
        case 4: return kVK_ANSI_4
        case 5: return kVK_ANSI_5
        case 6: return kVK_ANSI_6
        case 7: return kVK_ANSI_7
        case 8: return kVK_ANSI_8
        default: return nil
        }
    }

    private static let signature: OSType = {
        let bytes = Array("UWTL".utf8)
        return bytes.reduce(0) { ($0 << 8) + OSType($1) }
    }()
}

private let hotkeyCallback: EventHandlerUPP = { _, event, userInfo in
    guard let userInfo else {
        return OSStatus(eventNotHandledErr)
    }

    let controller = Unmanaged<HotkeyController>.fromOpaque(userInfo).takeUnretainedValue()
    return controller.handle(event: event)
}
