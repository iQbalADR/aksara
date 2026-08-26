import Foundation

/// Startup configuration for the `Localizer`.
///
/// Mirrors the Kotlin `LocalizationConfig` (see `android/`). Keep the two in sync —
/// any field added here is a PR obligation to add on the other platform.
///
/// Aksara is **network-agnostic**: there's no remote URL or fetching here. You
/// download bundles however you like and feed them in with `Localizer.applyBundle(_:for:)`.
public struct LocalizationConfig {
    /// Language shown first. Its bundled JSON is loaded **synchronously** at startup.
    public var defaultLanguage: String
    /// Used when a key is missing in the active language.
    public var fallbackLanguage: String
    /// Base name of the bundled default-language resource (e.g. `"en"` → `en.json`).
    /// Informational; languages are loaded by `<code>.json`.
    public var bundledResource: String?
    /// Bundle to load bundled JSON from. Defaults to `.main`; tests pass `.module`.
    public var bundle: Bundle
    /// Warm-start cache location. Defaults to `<Caches>/Aksara`. Bundles passed to
    /// `applyBundle(_:for:)` are persisted here and re-loaded on next launch.
    public var cacheDirectory: URL?
    /// Turns raw bundle bytes into the flat lookup map. Defaults to `I18nextParser`;
    /// inject your own to accept a custom JSON format/model.
    public var parser: TranslationParser

    public init(
        defaultLanguage: String,
        fallbackLanguage: String,
        bundledResource: String? = nil,
        bundle: Bundle = .main,
        cacheDirectory: URL? = nil,
        parser: TranslationParser = I18nextParser()
    ) {
        self.defaultLanguage = defaultLanguage
        self.fallbackLanguage = fallbackLanguage
        self.bundledResource = bundledResource
        self.bundle = bundle
        self.cacheDirectory = cacheDirectory
        self.parser = parser
    }
}
