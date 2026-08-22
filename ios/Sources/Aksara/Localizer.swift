import Foundation

/// The runtime entry point. Loads translations, resolves keys in O(1), and swaps in
/// new tables atomically for language switches and OTA updates.
///
/// Public API is mirrored 1:1 with the Kotlin `Localizer` — see `android/`.
///
/// Threading: `t(...)` is synchronous and safe to call from the main thread (it's a
/// brief lock + one dictionary lookup). Bundled languages load synchronously (they're
/// small — the spec requires first render never wait on disk). Remote updates fetch
/// and parse off-main via `async`, then publish the finished table to the main thread.
public final class Localizer: @unchecked Sendable {
    /// Shared instance used by the SwiftUI/UIKit layers. You may also create your own.
    public static let shared = Localizer()

    private let lock = NSLock()
    private var config: LocalizationConfig?
    private var _language: String
    private var active: TranslationTable?
    private var fallback: TranslationTable?
    private var cache: DiskCache?
    private var updater: OTAUpdater?
    private let plurals: PluralResolver

    public init(pluralResolver: PluralResolver = .default) {
        self.plurals = pluralResolver
        self._language = "en"
    }

    // MARK: - Configuration

    /// Configure and perform the synchronous first load. Call once at startup.
    public func configure(_ config: LocalizationConfig) {
        configure(config, fetcherOverride: nil)
    }

    /// Internal seam so tests can inject a mock `RemoteBundleFetcher`.
    func configure(_ config: LocalizationConfig, fetcherOverride: RemoteBundleFetcher?) {
        let cache = DiskCache(directory: config.cacheDirectory)

        lock.lock()
        self.config = config
        self._language = config.defaultLanguage
        self.cache = cache
        if let remote = config.remoteURL {
            let fetcher = fetcherOverride
                ?? URLSessionBundleFetcher(pinnedCertificateHashes: config.pinnedCertificateHashes)
            self.updater = OTAUpdater(remoteBaseURL: remote, fetcher: fetcher, cache: cache)
        } else {
            self.updater = nil
        }
        lock.unlock()

        // 1) Synchronous bundled load — first render must not wait on disk/network.
        let defaultTable = loadBundledTable(language: config.defaultLanguage, config: config)
        let fallbackTable = config.fallbackLanguage == config.defaultLanguage
            ? defaultTable
            : loadBundledTable(language: config.fallbackLanguage, config: config)

        lock.lock()
        self.active = defaultTable
        self.fallback = fallbackTable
        lock.unlock()

        // 2) Prefer a last-good cached remote bundle over the bundled default, if present.
        if let cached = cache.loadBundle(language: config.defaultLanguage),
           let cachedTable = try? TranslationTable.make(language: config.defaultLanguage, data: cached) {
            swapActive(cachedTable, language: config.defaultLanguage, notify: true)
        }
    }

    // MARK: - Lookup

    /// Resolve `key`, interpolating `{{var}}` placeholders from `args`.
    public func t(_ key: String, args: [String: Any] = [:]) -> String {
        resolve(key, category: nil, args: stringify(args))
    }

    /// Resolve a plural `key` for `count`. `{{count}}` is auto-injected into `args`.
    public func t(_ key: String, count: Int, args: [String: Any] = [:]) -> String {
        lock.lock(); let language = _language; lock.unlock()
        let category = plurals.category(for: count, language: language)
        var merged = stringify(args)
        if merged["count"] == nil { merged["count"] = String(count) }
        return resolve(key, category: category, args: merged)
    }

    private func resolve(_ key: String, category: PluralCategory?, args: [String: String]) -> String {
        lock.lock()
        let active = self.active
        let fallback = self.fallback
        lock.unlock()

        let candidates: [String]
        if let category {
            // Try the exact category, then fall back to `other` (always required).
            candidates = category == .other ? [key + ".other"] : [key + "." + category.rawValue, key + ".other"]
        } else {
            candidates = [key]
        }

        // Fallback chain: active language → fallback language → the raw key itself.
        if let template = firstMatch(candidates, in: active) {
            return Interpolator.interpolate(template, args: args)
        }
        if let template = firstMatch(candidates, in: fallback) {
            return Interpolator.interpolate(template, args: args)
        }
        return key
    }

    private func firstMatch(_ keys: [String], in table: TranslationTable?) -> String? {
        guard let table else { return nil }
        for key in keys {
            if let value = table.value(for: key) { return value }
        }
        return nil
    }

    // MARK: - Language switching

    /// Switch the active language and trigger a live UI update. No-op if no bundle
    /// (cached or bundled) is available for `language`.
    public func setLanguage(_ language: String) {
        lock.lock(); let config = self.config; let cache = self.cache; lock.unlock()
        guard let config else { return }

        let table: TranslationTable?
        if let cached = cache?.loadBundle(language: language),
           let cachedTable = try? TranslationTable.make(language: language, data: cached) {
            table = cachedTable
        } else {
            table = loadBundledTable(language: language, config: config)
        }

        guard let table else { return } // keep current — never blank the UI
        swapActive(table, language: language, notify: true)
    }

    // MARK: - OTA

    /// Fetch a newer bundle for the active language and atomically swap it in.
    /// Keeps last-good on any failure. Returns `.skipped` if no `remoteURL` is set.
    @discardableResult
    public func checkForUpdates() async -> UpdateResult {
        // Read shared state through a synchronous helper — never hold the lock
        // across an `await`.
        let (updater, language) = updateSnapshot()
        guard let updater else { return .skipped }

        let (result, table) = await updater.checkForUpdates(language: language)
        if case .updated = result, let table {
            swapActive(table, language: language, notify: true)
        }
        return result
    }

    private func updateSnapshot() -> (OTAUpdater?, String) {
        lock.lock(); defer { lock.unlock() }
        return (updater, _language)
    }

    // MARK: - Introspection

    public var currentLanguage: String {
        lock.lock(); defer { lock.unlock() }
        return _language
    }

    /// Number of keys in the active table (handy for smoke tests / benchmarks).
    public var activeKeyCount: Int {
        lock.lock(); defer { lock.unlock() }
        return active?.count ?? 0
    }

    // MARK: - Internals

    /// The atomic swap: replace the single immutable reference, then broadcast.
    private func swapActive(_ table: TranslationTable, language: String, notify: Bool) {
        lock.lock()
        self.active = table
        self._language = language
        lock.unlock()
        if notify { postChange() }
    }

    private func postChange() {
        let post = { NotificationCenter.default.post(name: .aksaraDidChange, object: self) }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }

    private func loadBundledTable(language: String, config: LocalizationConfig) -> TranslationTable? {
        guard let url = config.bundle.url(forResource: language, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? TranslationTable.make(language: language, data: data)
    }

    private func stringify(_ args: [String: Any]) -> [String: String] {
        guard !args.isEmpty else { return [:] }
        var out: [String: String] = [:]
        out.reserveCapacity(args.count)
        for (key, value) in args {
            if let s = value as? String {
                out[key] = s
            } else if let c = value as? CustomStringConvertible {
                out[key] = c.description
            } else {
                out[key] = String(describing: value)
            }
        }
        return out
    }
}
