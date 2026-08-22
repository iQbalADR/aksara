package com.aksara

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Flattens a nested i18next-style JSON object into a single `Map<String, String>`
 * keyed by dot-path, so every `t(...)` lookup is one O(1) hash hit instead of a
 * per-call tree walk.
 *
 * - Nested objects become dotted paths: `{"common":{"login":"…"}}` -> `common.login`.
 * - Arrays are indexed: `{"steps":["a","b"]}` -> `steps.0`, `steps.1`.
 * - Plural sub-keys are just nested keys: `common.items.one`, `common.items.other`.
 * - Numbers/bools are stringified; `null` is skipped.
 *
 * Mirror of the Swift `Flattener`.
 */
internal object Flattener {
    fun flatten(obj: JsonObject): Map<String, String> {
        val out = LinkedHashMap<String, String>(obj.size * 4)
        flatten(obj, "", out)
        return out
    }

    private fun flatten(element: JsonElement, prefix: String, out: MutableMap<String, String>) {
        when (element) {
            is JsonObject -> for ((key, child) in element) {
                val path = if (prefix.isEmpty()) key else "$prefix.$key"
                flatten(child, path, out)
            }
            is JsonArray -> element.forEachIndexed { index, child ->
                val path = if (prefix.isEmpty()) index.toString() else "$prefix.$index"
                flatten(child, path, out)
            }
            JsonNull -> Unit // skip nulls
            is JsonPrimitive -> out[prefix] = element.content
        }
    }
}
