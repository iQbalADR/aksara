package com.aksara

import java.util.concurrent.ConcurrentHashMap

/**
 * CLDR plural categories. [key] matches the JSON sub-keys used in bundles
 * (`zero`, `one`, `two`, `few`, `many`, `other`). `other` is always the fallback.
 *
 * Mirror of the Swift `PluralCategory`.
 */
enum class PluralCategory(val key: String) {
    ZERO("zero"), ONE("one"), TWO("two"), FEW("few"), MANY("many"), OTHER("other")
}

/**
 * One language family's plural rule. Adding a language = adding one of these and
 * registering it — the prime "good first issue" contributor surface.
 */
interface PluralRule {
    /** [count] is the raw (possibly negative) count; implementations normalize. */
    fun category(count: Int): PluralCategory
}

/**
 * Maps `(language, count) -> PluralCategory`. Thread-safe so contributors' rules can
 * be registered at startup and read from any thread during `t(...)`.
 *
 * Mirror of the Swift `PluralResolver`.
 */
class PluralResolver(rules: Map<String, PluralRule> = emptyMap()) {
    private val rules = ConcurrentHashMap(rules)
    private val fallbackRule: PluralRule = EnglishPluralRule()

    /**
     * Register (or override) the rule for a language. [language] is normalized to its
     * base code, so `"en-US"` and `"en"` share a rule.
     */
    fun register(rule: PluralRule, language: String) {
        rules[normalize(language)] = rule
    }

    fun category(count: Int, language: String): PluralCategory =
        (rules[normalize(language)] ?: fallbackRule).category(count)

    companion object {
        /** Shared resolver seeded with the built-in language families. */
        val default: PluralResolver by lazy { makeDefault() }

        /** `"en-US"` / `"pt_BR"` -> `"en"` / `"pt"`. */
        internal fun normalize(language: String): String {
            val lower = language.lowercase()
            val base = lower.split('-', '_').firstOrNull()
            return if (base.isNullOrEmpty()) lower else base
        }

        private fun makeDefault(): PluralResolver = PluralResolver(
            mapOf(
                "en" to EnglishPluralRule(),
                "id" to OtherOnlyPluralRule(), // Indonesian — no plural distinction
                "ja" to OtherOnlyPluralRule(), // Japanese — no plural distinction
                "ar" to ArabicPluralRule(),    // Arabic — full six-category set
            )
        )
    }
}
