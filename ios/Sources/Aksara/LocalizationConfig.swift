import Foundation

/// Startup configuration for the `Localizer`.
///
/// Mirrors the Kotlin `Config` (see `android/`). Keep the two in sync — any field
/// added here is a PR obligation to add on the other platform.
public struct LocalizationConfig {
    /// Language shown first. Its bundled JSON is loaded **synchronously** at startup.
    public var defaultLanguage: String
    /// Used when a key is missing in the active language.
    public var fallbackLanguage: String
    /// Base name of the bundled default-language resource (e.g. `"en"` → `en.json`).
    /// Informational; languages are loaded by `<code>.json`.
    public var bundledResource: String?
    /// Base URL of the OTA endpoint; per-language files live at `<remoteURL>/<code>.json`.
    public var remoteURL: URL?
    /// Bundle to load bundled JSON from. Defaults to `.main`; tests pass `.module`.
    public var bundle: Bundle
    /// `base64(SHA-256(DER cert))` pins for the OTA endpoint. Empty = no pinning.
    public var pinnedCertificateHashes: Set<String>
    /// Override the disk-cache location (tests). Defaults to `<Caches>/Aksara`.
    public var cacheDirectory: URL?

    public init(
        defaultLanguage: String,
        fallbackLanguage: String,
        bundledResource: String? = nil,
        remoteURL: URL? = nil,
        bundle: Bundle = .main,
        pinnedCertificateHashes: Set<String> = [],
        cacheDirectory: URL? = nil
    ) {
        self.defaultLanguage = defaultLanguage
        self.fallbackLanguage = fallbackLanguage
        self.bundledResource = bundledResource
        self.remoteURL = remoteURL
        self.bundle = bundle
        self.pinnedCertificateHashes = pinnedCertificateHashes
        self.cacheDirectory = cacheDirectory
    }
}
