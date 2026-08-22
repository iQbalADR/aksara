import Foundation
import Combine
import Aksara

/// SwiftUI-facing wrapper around `Localizer`. It publishes a `revision` counter that
/// bumps on every language switch / OTA swap; any view observing this manager
/// (via `@StateObject` / `@ObservedObject`, or through `LocText`) re-renders
/// automatically when a table swaps.
///
/// Implemented with `ObservableObject`/`@Published` (iOS 13+) rather than the iOS-17
/// `@Observable` macro, so the whole SwiftUI layer works down to **iOS 15**.
public final class LocalizationManager: ObservableObject {
    /// Backed by `Localizer.shared` — the same table the rest of the app reads.
    public static let shared = LocalizationManager()

    /// Bumped on every table swap. `@Published` drives `objectWillChange`, which is
    /// what re-renders observing views.
    @Published public private(set) var revision: Int = 0

    private let localizer: Localizer
    private var observer: NSObjectProtocol?

    public init(localizer: Localizer = .shared) {
        self.localizer = localizer
        // Delivered on the main queue, so the @Published mutation is main-thread safe.
        observer = NotificationCenter.default.addObserver(
            forName: .aksaraDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.revision &+= 1
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Mirrored API

    public func configure(_ config: LocalizationConfig) {
        localizer.configure(config)
    }

    public func t(_ key: String, args: [String: Any] = [:]) -> String {
        localizer.t(key, args: args)
    }

    public func t(_ key: String, count: Int, args: [String: Any] = [:]) -> String {
        localizer.t(key, count: count, args: args)
    }

    public var currentLanguage: String {
        localizer.currentLanguage
    }

    public func setLanguage(_ language: String) {
        localizer.setLanguage(language)
    }

    @discardableResult
    public func checkForUpdates() async -> UpdateResult {
        await localizer.checkForUpdates()
    }
}
