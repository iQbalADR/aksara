import Foundation

/// CLDR plural categories. Raw values match the JSON sub-keys used in bundles
/// (`zero`, `one`, `two`, `few`, `many`, `other`). `other` is always the fallback.
public enum PluralCategory: String, CaseIterable, Sendable {
    case zero, one, two, few, many, other
}

/// One language family's plural rule. Adding a language = adding one of these and
/// registering it — the prime "good first issue" contributor surface.
public protocol PluralRule: Sendable {
    /// `count` is the raw (possibly negative) count; implementations normalize.
    func category(for count: Int) -> PluralCategory
}

/// Maps `(language, count) -> PluralCategory`. Thread-safe so contributors' rules
/// can be registered at startup and read from any thread during `t(...)`.
public final class PluralResolver: @unchecked Sendable {
    /// Shared resolver seeded with the built-in language families.
    public static let `default` = PluralResolver.makeDefault()

    private let lock = NSLock()
    private var rules: [String: PluralRule]
    /// Used when a language has no registered rule (English-style: one vs other).
    private let fallbackRule: PluralRule = EnglishPluralRule()

    public init(rules: [String: PluralRule] = [:]) {
        self.rules = rules
    }

    /// Register (or override) the rule for a language. `language` is normalized to
    /// its base code, so `"en-US"` and `"en"` share a rule.
    public func register(_ rule: PluralRule, for language: String) {
        lock.lock(); defer { lock.unlock() }
        rules[Self.normalize(language)] = rule
    }

    public func category(for count: Int, language: String) -> PluralCategory {
        lock.lock()
        let rule = rules[Self.normalize(language)]
        lock.unlock()
        return (rule ?? fallbackRule).category(for: count)
    }

    /// `"en-US"` / `"pt_BR"` → `"en"` / `"pt"`.
    static func normalize(_ language: String) -> String {
        let lower = language.lowercased()
        if let base = lower.split(whereSeparator: { $0 == "-" || $0 == "_" }).first {
            return String(base)
        }
        return lower
    }

    static func makeDefault() -> PluralResolver {
        PluralResolver(rules: [
            "en": EnglishPluralRule(),
            "id": OtherOnlyPluralRule(),  // Indonesian — no plural distinction
            "ja": OtherOnlyPluralRule(),  // Japanese — no plural distinction
            "ar": ArabicPluralRule(),     // Arabic — full six-category set
        ])
    }
}
