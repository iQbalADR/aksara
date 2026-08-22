import Foundation

/// An **immutable** snapshot of one language's translations: the flattened
/// dot-path → template map plus optional metadata.
///
/// The whole OTA/live-update design hinges on immutability — updates build a brand
/// new `TranslationTable` and swap a single reference. Nothing is ever mutated in
/// place, so a `t(...)` in flight always sees a consistent table.
public struct TranslationTable: Sendable {
    public let language: String
    /// Flattened `dot.path` → raw template (with `{{var}}` placeholders intact).
    public let entries: [String: String]
    /// Optional `_version` from the bundle, used as a cheap change signal alongside ETag.
    public let version: String?

    public init(language: String, entries: [String: String], version: String? = nil) {
        self.language = language
        self.entries = entries
        self.version = version
    }

    public var count: Int { entries.count }

    @inline(__always)
    public func value(for key: String) -> String? { entries[key] }
}

extension TranslationTable {
    /// Validate + parse `data` into an immutable table. Throws `SchemaValidationError`
    /// if the payload isn't a well-formed translation bundle.
    static func make(language: String, data: Data) throws -> TranslationTable {
        var json = try SchemaValidator.validated(data)

        // Pull `_version` out of the graph so it doesn't pollute the key space.
        var version: String?
        if let raw = json.removeValue(forKey: "_version") {
            if let s = raw as? String { version = s }
            else if let n = raw as? NSNumber { version = n.stringValue }
        }

        let entries = Flattener.flatten(json)
        return TranslationTable(language: language, entries: entries, version: version)
    }
}
