import Foundation

/// Turns raw bundle bytes into Aksara's flat lookup map.
///
/// The returned dictionary is the contract the rest of the runtime relies on:
/// - keys are **dot-paths** (`common.login`);
/// - plural forms are `key.<category>` where `<category>` is a CLDR plural key
///   (`zero`/`one`/`two`/`few`/`many`/`other`);
/// - values are templates containing `{{var}}` placeholders.
///
/// Aksara never fetches anything itself — the consumer downloads the bytes however
/// they like and hands them to `Localizer.applyBundle(_:for:)`. Inject a custom
/// `TranslationParser` via `LocalizationConfig.parser` to accept **any** on-the-wire
/// JSON shape (your own model); the built-in ``I18nextParser`` reads nested i18next JSON.
public protocol TranslationParser: Sendable {
    /// Parse `data` (the raw bundle for `language`) into the flat lookup map.
    /// Throw to reject a malformed payload — the caller keeps the current table.
    func parse(_ data: Data, language: String) throws -> [String: String]
}

/// Default parser: nested i18next-style JSON → flat dot-path map.
///
/// Validates the payload (rejecting non-object roots and `null` leaves), strips the
/// reserved `_version` meta key, then flattens nested objects/arrays — plural
/// categories are ordinary nested keys (`items.one`, `items.other`).
public struct I18nextParser: TranslationParser {
    public init() {}

    public func parse(_ data: Data, language: String) throws -> [String: String] {
        var object = try SchemaValidator.validated(data)
        object.removeValue(forKey: "_version") // reserved meta key, not a translation
        return Flattener.flatten(object)
    }
}
