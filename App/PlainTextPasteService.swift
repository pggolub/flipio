import AppKit
import ApplicationServices

@MainActor
final class PlainTextPasteService {
    static let shared = PlainTextPasteService()

    private var isPasting = false

    func paste() async {
        guard !isPasting else { return }
        isPasting = true
        defer { isPasting = false }

        let pasteboard = NSPasteboard.general
        guard let item = pasteboard.pasteboardItems?.first else { return }

        var savedData: [NSPasteboard.PasteboardType: Data] = [:]
        for type in item.types {
            savedData[type] = item.data(forType: type)
        }
        guard let plainTextData = savedData[.string] else { return }

        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setData(plainTextData, forType: .string)

        defer {
            pasteboard.declareTypes(Array(savedData.keys), owner: nil)
            for (type, data) in savedData {
                pasteboard.setData(data, forType: type)
            }
        }

        for keyDown in [true, false] {
            let source = CGEventSource(stateID: .combinedSessionState)
            if let event = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: keyDown) {
                event.flags = .maskCommand
                event.post(tap: .cghidEventTap)
            }
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}