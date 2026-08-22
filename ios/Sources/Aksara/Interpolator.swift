import Foundation

/// Replaces `{{var}}` placeholders in a template with values from `args`.
///
/// - Whitespace inside the braces is tolerated: `{{ name }}` == `{{name}}`.
/// - A missing variable leaves the placeholder **intact** (`{{name}}`) rather than
///   silently dropping it — a visible gap is easier to catch than an empty string.
/// - Fast path: templates with no `{{` are returned untouched.
///
/// This is deliberately a plain string scan. Per the spec we only cache compiled
/// templates if profiling shows a hot path — no pre-optimization.
enum Interpolator {
    static func interpolate(_ template: String, args: [String: String]) -> String {
        guard !args.isEmpty, template.contains("{{") else { return template }

        var result = ""
        result.reserveCapacity(template.count)
        var rest = Substring(template)

        while let open = rest.range(of: "{{") {
            result += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]

            guard let close = afterOpen.range(of: "}}") else {
                // Unterminated placeholder — emit the remainder verbatim and stop.
                result += rest[open.lowerBound...]
                return result
            }

            let rawName = afterOpen[..<close.lowerBound]
            let name = rawName.trimmingCharacters(in: .whitespaces)
            if let value = args[name] {
                result += value
            } else {
                result += "{{" + rawName + "}}"
            }
            rest = afterOpen[close.upperBound...]
        }

        result += rest
        return result
    }
}
