import Foundation

/// An **immutable** snapshot of one language's translations: the flattened
/// dot-path → template map produced by a `TranslationParser`.
///
/// The whole live-update design hinges on immutability — applying a new bundle builds
/// a brand new `TranslationTable` and swaps a single reference. Nothing is mutated in
/// place, so a `t(...)` in flight always sees a consistent table.
public struct TranslationTable: Sendable {
    public let language: String
    /// Flattened `dot.path` → raw template (with `{{var}}` placeholders intact).
    public let entries: [String: String]

    public init(language: String, entries: [String: String]) {
        self.language = language
        self.entries = entries
    }

    public var count: Int { entries.count }

    @inline(__always)
    public func value(for key: String) -> String? { entries[key] }
}
