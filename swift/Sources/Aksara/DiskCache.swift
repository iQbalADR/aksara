import Foundation

/// Persists the last-good remote bundle (and its ETag) per language.
///
/// On launch the `Localizer` loads the cached bundle — if any — **before** hitting
/// the network, so a returning user sees the latest translations offline and the
/// first render never waits on a request.
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
    private func etagURL(_ language: String) -> URL {
        directory.appendingPathComponent("\(language).etag")
    }

    public func saveBundle(_ data: Data, etag: String?, language: String) {
        try? data.write(to: bundleURL(language), options: .atomic)
        if let etag {
            try? Data(etag.utf8).write(to: etagURL(language), options: .atomic)
        }
    }

    public func loadBundle(language: String) -> Data? {
        try? Data(contentsOf: bundleURL(language))
    }

    public func loadETag(language: String) -> String? {
        guard let data = try? Data(contentsOf: etagURL(language)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func clear(language: String) {
        try? fileManager.removeItem(at: bundleURL(language))
        try? fileManager.removeItem(at: etagURL(language))
    }
}
