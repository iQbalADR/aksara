import Foundation

/// Errors thrown by the `Localizer` itself (parser errors propagate from the
/// injected `TranslationParser`).
public enum AksaraError: Error, Equatable {
    /// `applyBundle`/`update` was called before `configure(_:)`.
    case notConfigured
}

/// The runtime entry point. Loads translations, resolves keys in O(1), and swaps in
/// new tables atomically for language switches and consumer-supplied bundle updates.
///
/// Public API is mirrored 1:1 with the Kotlin `Localizer` — see `android/`.
///
/// **Network-agnostic:** Aksara never downloads anything. You fetch bundles however
/// you like (URLSession, Alamofire, a CDN SDK, a file on disk…) and hand the bytes to
/// `applyBundle(_:for:)`. How those bytes are parsed is pluggable too — see
/// `TranslationParser`.
///
/// Threading: `t(...)` is synchronous and safe on the main thread (a brief lock + one
/// dictionary lookup). Bundled languages load synchronously at `configure`. `applyBundle`
/// parses on the calling thread — call it off the main thread for large payloads (the
/// `update(for:using:)` helper already runs in an async context).
public final class Localizer: @unchecked Sendable {
    /// Shared instance used by the SwiftUI/UIKit layers. You may also create your own.
    public static let shared = Localizer()

    private let lock = NSLock()
    private var config: LocalizationConfig?
    private var _language: String
    private var active: TranslationTable?
    private var fallback: TranslationTable?
    private var cache: DiskCache?
    private let plurals: PluralResolver

    public init(pluralResolver: PluralResolver = .default) {
        self.plurals = pluralResolver
        self._language = "en"
    }

    // MARK: - Configuration

    /// Configure and perform the synchronous first load. Call once at startup.
    public func configure(_ config: LocalizationConfig) {
        let cache = DiskCache(directory: config.cacheDirectory)

        lock.lock()
        self.config = config
        self._language = config.defaultLanguage
        self.cache = cache
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

        // 2) Prefer a last-good cached bundle (from a previous applyBundle) over the
        //    bundled default, if present and still parseable with the current parser.
        if let cached = cache.loadBundle(language: config.defaultLanguage),
           let entries = try? config.parser.parse(cached, language: config.defaultLanguage) {
            swapActive(TranslationTable(language: config.defaultLanguage, entries: entries),
                       language: config.defaultLanguage, notify: true)
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
           let entries = try? config.parser.parse(cached, language: language) {
            table = TranslationTable(language: language, entries: entries)
        } else {
            table = loadBundledTable(language: language, config: config)
        }

        guard let table else { return } // keep current — never blank the UI
        swapActive(table, language: language, notify: true)
    }

    // MARK: - Applying consumer-fetched bundles

    /// Feed a freshly-downloaded bundle into the runtime. **You** fetch the bytes
    /// (any transport, any auth); Aksara parses, validates, and swaps.
    ///
    /// - The configured `TranslationParser` parses `data`. If it throws, the current
    ///   table is kept (last-good) and the error is re-thrown.
    /// - On success the bytes are persisted to the warm-start cache for `language`.
    /// - If `language` is the active or fallback language, the visible table is swapped
    ///   and observers are notified. Otherwise it's cached for a later `setLanguage`.
    ///
    /// - Throws: `AksaraError.notConfigured`, or whatever the parser throws.
    public func applyBundle(_ data: Data, for language: String) throws {
        lock.lock(); let config = self.config; let cache = self.cache; lock.unlock()
        guard let config else { throw AksaraError.notConfigured }

        // Parse first — a bad payload must never replace last-good.
        let entries = try config.parser.parse(data, language: language)
        cache?.saveBundle(data, language: language)

        let table = TranslationTable(language: language, entries: entries)
        lock.lock()
        var changed = false
        if language == _language { active = table; changed = true }
        if language == config.fallbackLanguage { fallback = table; changed = true }
        lock.unlock()
        if changed { postChange() }
    }

    /// Convenience: run your own async `fetch` for `language`, then apply the result.
    /// Aksara stays agnostic — `fetch` is entirely yours.
    ///
    /// ```swift
    /// try await loc.update(for: "id") { lang in
    ///     try await myClient.download("https://cdn.example.com/i18n/\(lang).json")
    /// }
    /// ```
    public func update(for language: String, using fetch: (String) async throws -> Data) async throws {
        let data = try await fetch(language)
        try applyBundle(data, for: language)
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
              let data = try? Data(contentsOf: url),
              let entries = try? config.parser.parse(data, language: language) else {
            return nil
        }
        return TranslationTable(language: language, entries: entries)
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
