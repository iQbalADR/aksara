import Foundation

/// Flattens a nested i18next-style JSON object into a single `[String: String]`
/// keyed by dot-path, so every `t(...)` lookup is one O(1) hash hit instead of a
/// per-call tree walk.
///
/// - Nested objects become dotted paths: `{"common":{"login":"…"}}` → `common.login`.
/// - Arrays are indexed: `{"steps":["a","b"]}` → `steps.0`, `steps.1`.
/// - Plural sub-keys are just nested keys: `common.items.one`, `common.items.other`.
///   Plural *selection* happens at lookup time (see `PluralResolver`).
/// - Numbers/bools are stringified so a stray non-string value can't blank a screen.
/// - `null` and unsupported values are dropped (they never reach here in practice
///   because `SchemaValidator` rejects them first).
enum Flattener {
    static func flatten(_ object: [String: Any]) -> [String: String] {
        var out: [String: String] = [:]
        out.reserveCapacity(object.count * 4)
        flatten(object, prefix: "", into: &out)
        return out
    }

    private static func flatten(_ value: Any, prefix: String, into out: inout [String: String]) {
        switch value {
        case let dict as [String: Any]:
            for (key, child) in dict {
                let path = prefix.isEmpty ? key : prefix + "." + key
                flatten(child, prefix: path, into: &out)
            }
        case let array as [Any]:
            for (index, child) in array.enumerated() {
                let path = prefix.isEmpty ? String(index) : prefix + "." + String(index)
                flatten(child, prefix: path, into: &out)
            }
        case let string as String:
            out[prefix] = string
        case let number as NSNumber:
            out[prefix] = number.stringValue
        default:
            break // null / unsupported — skip
        }
    }
}
