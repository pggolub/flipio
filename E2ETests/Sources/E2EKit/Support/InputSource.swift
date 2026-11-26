import Carbon.HIToolbox
import Foundation

public enum Layout: Equatable, Sendable, CustomStringConvertible {
    case us
    case ru
    case other(String)

    init(sourceID: String) {
        switch sourceID {
        case "com.apple.keylayout.US", "com.apple.keylayout.ABC":
            self = .us
        case let id where id.hasPrefix("com.apple.keylayout.Russian"):
            self = .ru
        default:
            self = .other(sourceID)
        }
    }

    public var description: String {
        switch self {
        case .us: return "U.S."
        case .ru: return "Russian"
        case .other(let id): return id
        }
    }
}

public enum InputSource {
    /// The current keyboard layout as seen by the system.
    public static func current() -> Layout {
        // TIS state in this process is refreshed by notifications delivered on the run loop.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let id = stringProperty(source, kTISPropertyInputSourceID)
        else {
            return .other("unknown")
        }
        return Layout(sourceID: id)
    }

    /// Selects a layout directly. Used only to set the starting state of a test.
    public static func select(_ layout: Layout) throws {
        guard let source = enabledSources().first(where: { $0.layout == layout })?.source else {
            throw E2EError.failed("Layout \(layout) is not enabled")
        }
        let status = TISSelectInputSource(source)
        guard status == noErr else {
            throw E2EError.failed("TISSelectInputSource(\(layout)) failed: \(status)")
        }
    }

    /// Enabled, selectable keyboard layouts.
    public static func enabledLayouts() -> [Layout] {
        enabledSources().map(\.layout)
    }

    private static func enabledSources() -> [(layout: Layout, source: TISInputSource)] {
        let filter = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return list.compactMap { source in
            guard boolProperty(source, kTISPropertyInputSourceIsSelectCapable),
                stringProperty(source, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String),
                let id = stringProperty(source, kTISPropertyInputSourceID)
            else {
                return nil
            }
            return (Layout(sourceID: id), source)
        }
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let raw = TISGetInputSourceProperty(source, key) else { return false }
        return Unmanaged<CFBoolean>.fromOpaque(raw).takeUnretainedValue() == kCFBooleanTrue
    }
}
