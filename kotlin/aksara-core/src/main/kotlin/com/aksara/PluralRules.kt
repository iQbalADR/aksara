package com.aksara

import kotlin.math.abs

// Built-in CLDR plural rules. One class per language family — the intended
// contributor pattern is to add a new class here (or your own) and register it via
// PluralResolver.register(...).
//
// Reference: https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html

/**
 * English family: `one` for exactly 1, `other` otherwise.
 * Also the fallback rule for any unregistered language.
 */
internal class EnglishPluralRule : PluralRule {
    override fun category(count: Int): PluralCategory =
        if (abs(count) == 1) PluralCategory.ONE else PluralCategory.OTHER
}

/**
 * Languages with no plural distinction (Indonesian, Japanese, Korean, Chinese,
 * Thai, Vietnamese, ...). Everything is `other`.
 */
internal class OtherOnlyPluralRule : PluralRule {
    override fun category(count: Int): PluralCategory = PluralCategory.OTHER
}

/** Arabic: the full six-category CLDR set. */
internal class ArabicPluralRule : PluralRule {
    override fun category(count: Int): PluralCategory {
        val n = abs(count)
        return when (n) {
            0 -> PluralCategory.ZERO
            1 -> PluralCategory.ONE
            2 -> PluralCategory.TWO
            else -> when (n % 100) {
                in 3..10 -> PluralCategory.FEW
                in 11..99 -> PluralCategory.MANY
                else -> PluralCategory.OTHER
            }
        }
    }
}
