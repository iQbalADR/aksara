package com.aksara

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * An **immutable** snapshot of one language's translations: the flattened dot-path
 * -> template map plus optional metadata.
 *
 * The whole OTA/live-update design hinges on immutability — updates build a brand new
 * table and swap a single reference. Nothing is mutated in place, so a `t(...)` in
 * flight always sees a consistent table.
 *
 * Mirror of the Swift `TranslationTable`.
 */
data class TranslationTable(
    val language: String,
    val entries: Map<String, String>,
    val version: String? = null,
) {
    val count: Int get() = entries.size

    fun value(key: String): String? = entries[key]

    companion object {
        /**
         * Validate + parse [bytes] into an immutable table. Throws
         * [SchemaValidationException] if the payload isn't a well-formed bundle.
         */
        fun make(language: String, bytes: ByteArray): TranslationTable {
            val json = SchemaValidator.validated(bytes)

            // Pull `_version` out of the graph so it doesn't pollute the key space.
            val mutable = json.toMutableMap()
            val version = (mutable.remove("_version") as? JsonPrimitive)?.content

            val entries = Flattener.flatten(JsonObject(mutable))
            return TranslationTable(language, entries, version)
        }
    }
}
