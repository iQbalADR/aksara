import Foundation

/// Persists the last-good bundle per language (raw bytes as applied).
///
/// This is a **local warm-start cache**, not a network cache — Aksara does no
/// fetching. On launch the `Localizer` re-parses the cached bytes (with the configured
/// `TranslationParser`) so a returning user sees the last applied translations before
/// the app re-downloads anything. Set `LocalizationConfig.cacheDirectory` to control
/// (or, if you handle persistence yourself, ignore this entirely).
public final class DiskCache: @unchecked Sendable {
    private let directory: URL
    private let fileManager = FileManager.default

    /// - Parameter directory: override the cache location (used by tests). Defaults
    ///   to `<Caches>/Aksara`.
    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = (try? FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )) ?? FileManager.default.temporaryDirectory
            self.directory = base.appendingPathComponent("Aksara", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func bundleURL(_ language: String) -> URL {
        directory.appendingPathComponent("\(language).json")
    }

    public func saveBundle(_ data: Data, language: String) {
        try? data.write(to: bundleURL(language), options: .atomic)
    }

    public func loadBundle(language: String) -> Data? {
        try? Data(contentsOf: bundleURL(language))
    }

    public func clear(language: String) {
        try? fileManager.removeItem(at: bundleURL(language))
    }
}
