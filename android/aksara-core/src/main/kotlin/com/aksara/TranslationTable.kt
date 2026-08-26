package com.aksara

/**
 * An **immutable** snapshot of one language's translations: the flattened dot-path
 * -> template map produced by a [TranslationParser].
 *
 * The whole live-update design hinges on immutability — applying a new bundle builds
 * a brand new table and swaps a single reference. Nothing is mutated in place, so a
 * `t(...)` in flight always sees a consistent table.
 */
data class TranslationTable(
    val language: String,
    val entries: Map<String, String>,
) {
    val count: Int get() = entries.size

    fun value(key: String): String? = entries[key]
}
