import AppKit
import ApplicationServices

final class KeyMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var buffer = ""
    private let evaluator: (String) -> String?
    private static let injectedMarker: Int64 = 0x54414E544F

    init(evaluator: @escaping (String) -> String?) { self.evaluator = evaluator }

    func start() {
        NSLog("Tanto: KeyMonitor.start()")
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        NSLog("Tanto: Accessibility = %@", trusted ? "true" : "false")
        guard trusted else {
            NSLog("Tanto: STOP — Accessibility permission is not available to this running build")
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                NSLog("Tanto: CGEventTap disabled (%u); re-enabling", type.rawValue)
                if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
            return monitor.handle(event)
        }

        tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                place: .headInsertEventTap,
                                options: .defaultTap,
                                eventsOfInterest: mask,
                                callback: callback,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            NSLog("Tanto: ERROR — failed to create CGEventTap")
            return
        }
        NSLog("Tanto: CGEventTap created")
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("Tanto: monitor started")
    }

    private func handle(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == Self.injectedMarker {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let text = Self.characters(from: event) ?? ""
        NSLog("Tanto: keyCode=%lld text=%@", keyCode, text.debugDescription)

        if keyCode == 51 {
            if !buffer.isEmpty { buffer.removeLast() }
            NSLog("Tanto: buffer = %@", buffer)
            return Unmanaged.passUnretained(event)
        }

        guard event.flags.intersection([.maskCommand, .maskControl]).isEmpty, !text.isEmpty else {
            buffer = ""
            NSLog("Tanto: buffer reset")
            return Unmanaged.passUnretained(event)
        }

        if text == "@" {
            buffer = "@"
        } else if buffer.hasPrefix("@"),
                  text.range(of: #"^[A-Za-z0-9._+-]+$"#, options: .regularExpression) != nil {
            buffer += text
            if buffer.count > 80 { buffer = "" }
        } else {
            buffer = ""
        }
        NSLog("Tanto: buffer = %@", buffer)

        if buffer.hasPrefix("@") {
            if let output = evaluator(buffer) {
                let trigger = buffer
                let count = buffer.count
                buffer = ""
                NSLog("Tanto: MATCH %@ -> %@", trigger, output)
                DispatchQueue.main.async {
                    Self.replacePreviousCharacters(count, with: output)
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    private static func characters(from event: CGEvent) -> String? {
        var length = 0
        var chars = [UniChar](repeating: 0, count: 16)
        event.keyboardGetUnicodeString(maxStringLength: chars.count,
                                       actualStringLength: &length,
                                       unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }

    private static func replacePreviousCharacters(_ count: Int, with text: String) {
        NSLog("Tanto: replacing %d chars", count)
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<count { postKey(51, source: src) }

        let pasteboard = NSPasteboard.general
        let oldItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var copy: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { copy[type] = data } }
            return copy.isEmpty ? nil : copy
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postKey(9, flags: .maskCommand, source: src)
        NSLog("Tanto: replacement posted")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            pasteboard.clearContents()
            guard let oldItems else { return }
            let restored = oldItems.map { dataByType -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in dataByType { item.setData(data, forType: type) }
                return item
            }
            pasteboard.writeObjects(restored)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], source: CGEventSource?) {
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: injectedMarker)
            event.post(tap: .cghidEventTap)
        }
    }
}
