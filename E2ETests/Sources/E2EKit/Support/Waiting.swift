import Foundation

/// Locations inside `E2ETests/`.
public enum Paths {
    public static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // E2EKit
        .deletingLastPathComponent()  // Sources
        .deletingLastPathComponent()  // E2ETests

    public static let fixtures = root.appendingPathComponent("Fixtures")
}

public enum E2EError: Error, CustomStringConvertible {
    case aborted(String)
    case timeout(String)
    case failed(String)

    public var description: String {
        switch self {
        case .aborted(let reason): return "Aborted: \(reason)"
        case .timeout(let what): return "Timed out waiting for \(what)"
        case .failed(let reason): return reason
        }
    }
}

/// Polls `condition` until it is true or `timeout` elapses.
public func waitUntil(
    _ what: String,
    timeout: Duration = .seconds(5),
    interval: Duration = .milliseconds(20),
    _ condition: () throws -> Bool
) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if try condition() { return }
        try await Task.sleep(for: interval)
    }
    throw E2EError.timeout(what)
}

enum Shell {
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
