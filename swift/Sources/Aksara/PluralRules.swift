import Foundation

// Built-in CLDR plural rules. One struct per language family — the intended
// contributor pattern is to add a new struct here (or in your own module) and
// `PluralResolver.default.register(_:for:)` it.
//
// Reference: https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html

/// English family: `one` for exactly 1, `other` otherwise.
/// Also the fallback rule for any unregistered language.
struct EnglishPluralRule: PluralRule {
    func category(for count: Int) -> PluralCategory {
        abs(count) == 1 ? .one : .other
    }
}

/// Languages with no plural distinction (Indonesian, Japanese, Korean, Chinese,
/// Thai, Vietnamese, …). Everything is `other`.
struct OtherOnlyPluralRule: PluralRule {
    func category(for count: Int) -> PluralCategory { .other }
}

/// Arabic: the full six-category CLDR set.
struct ArabicPluralRule: PluralRule {
    func category(for count: Int) -> PluralCategory {
        let n = abs(count)
        switch n {
        case 0: return .zero
        case 1: return .one
        case 2: return .two
        default:
            let mod100 = n % 100
            if (3...10).contains(mod100) { return .few }
            if (11...99).contains(mod100) { return .many }
            return .other
        }
    }
}
