import Foundation

/// Why a downloaded (or bundled) payload was rejected. Callers keep last-good on any of these.
public enum SchemaValidationError: Error, Equatable, Sendable {
    case notJSON
    case topLevelNotObject
    case unsupportedValue(path: String)
}

/// Validates a bundle **before** it is allowed to replace the live table.
///
/// A translation bundle must be a JSON object whose leaves are strings (or numbers,
/// which we coerce). Anything else — a top-level array, a `null` leaf, arbitrary
/// binary — is rejected so a malformed or poisoned payload can never blank the UI.
enum SchemaValidator {
    /// Parse + validate, returning the raw object graph on success.
    static func validated(_ data: Data) throws -> [String: Any] {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            throw SchemaValidationError.notJSON
        }
        guard let dict = object as? [String: Any] else {
            throw SchemaValidationError.topLevelNotObject
        }
        try validate(dict, path: "")
        return dict
    }

    private static func validate(_ value: Any, path: String) throws {
        switch value {
        case let dict as [String: Any]:
            for (key, child) in dict {
                try validate(child, path: path.isEmpty ? key : path + "." + key)
            }
        case let array as [Any]:
            for (index, child) in array.enumerated() {
                try validate(child, path: path + "." + String(index))
            }
        case is String, is NSNumber:
            return
        default:
            // NSNull and anything unexpected.
            throw SchemaValidationError.unsupportedValue(path: path.isEmpty ? "<root>" : path)
        }
    }
}
