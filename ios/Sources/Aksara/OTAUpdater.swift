import Foundation

/// Outcome of an OTA check, returned to callers of `Localizer.checkForUpdates()`.
public enum UpdateResult: Equatable, Sendable {
    /// A new bundle was fetched, validated, cached, and (by the caller) swapped in.
    case updated(language: String)
    /// Server said nothing changed (`304`) — current table kept.
    case notModified
    /// No remote configured — nothing to do.
    case skipped
    /// Network failure or malformed payload — last-good table kept.
    case failed
}

/// The OTA state machine: conditional fetch → schema-validate → build immutable
/// table → persist last-good. It never touches the live table itself; it hands the
/// built table back to the `Localizer`, which owns the atomic swap.
///
/// Kept free of `URLSession` and UI concerns so it's unit-testable with a mock
/// `RemoteBundleFetcher` and a temp `DiskCache`.
final class OTAUpdater {
    private let remoteBaseURL: URL
    private let fetcher: RemoteBundleFetcher
    private let cache: DiskCache

    init(remoteBaseURL: URL, fetcher: RemoteBundleFetcher, cache: DiskCache) {
        self.remoteBaseURL = remoteBaseURL
        self.fetcher = fetcher
        self.cache = cache
    }

    /// Fetch `<base>/<language>.json` conditionally and, on a valid change, return a
    /// freshly built table for the caller to swap in.
    ///
    /// Parsing + validation run here (already off the main thread inside the async
    /// call), so the caller only does the cheap reference swap on main.
    func checkForUpdates(language: String) async -> (result: UpdateResult, table: TranslationTable?) {
        let url = remoteBaseURL.appendingPathComponent("\(language).json")
        let etag = cache.loadETag(language: language)

        do {
            let outcome = try await fetcher.fetch(url: url, etag: etag)
            switch outcome {
            case .notModified:
                return (.notModified, nil)

            case let .updated(data, newETag):
                // Validate BEFORE anything is persisted or swapped.
                let table = try TranslationTable.make(language: language, data: data)
                // Only now is it "last-good".
                cache.saveBundle(data, etag: newETag, language: language)
                return (.updated(language: language), table)
            }
        } catch {
            // Network error or schema rejection — keep whatever we already have.
            return (.failed, nil)
        }
    }
}
