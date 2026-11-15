import AppKit
import Combine
import Sparkle

/// Owns the Sparkle updater and exposes the pieces the UI needs.
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    @Published private(set) var canCheckForUpdates = false

    private var controller: SPUStandardUpdaterController!
    private var cancellable: AnyCancellable?

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set {
            objectWillChange.send()
            controller.updater.automaticallyChecksForUpdates = newValue
        }
    }

    private override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        cancellable = controller.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in self?.canCheckForUpdates = value }
    }

    func checkForUpdates() {
        // Flipio is an accessory (menu bar) app; bring Sparkle's dialog to the front.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}

extension UpdateManager: SPUStandardUserDriverDelegate {
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    // Scheduled (background) checks would otherwise show their alert behind other apps.
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard handleShowingUpdate else { return }
        Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
    }
}
