package com.aksara

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * Why a downloaded (or bundled) payload was rejected. Callers keep last-good on any
 * of these. Mirror of the Swift `SchemaValidationError`.
 */
sealed class SchemaValidationException(message: String) : Exception(message) {
    object NotJson : SchemaValidationException("payload is not valid JSON")
    object TopLevelNotObject : SchemaValidationException("top-level JSON is not an object")
    class UnsupportedValue(val path: String) : SchemaValidationException("unsupported value at $path")
}

/**
 * Validates a bundle **before** it is allowed to replace the live table.
 *
 * A translation bundle must be a JSON object whose leaves are strings (or numbers,
 * which we coerce). Anything else — a top-level array, a `null` leaf, arbitrary
 * bytes — is rejected so a malformed or poisoned payload can never blank the UI.
 */
internal object SchemaValidator {
    private val json = Json { isLenient = false }

    fun validated(bytes: ByteArray): JsonObject {
        val element: JsonElement = try {
            json.parseToJsonElement(bytes.decodeToString())
        } catch (e: Exception) {
            throw SchemaValidationException.NotJson
        }
        val obj = element as? JsonObject ?: throw SchemaValidationException.TopLevelNotObject
        validate(obj, "")
        return obj
    }

    private fun validate(element: JsonElement, path: String) {
        when (element) {
            is JsonObject -> for ((key, child) in element) {
                validate(child, if (path.isEmpty()) key else "$path.$key")
            }
            is JsonArray -> element.forEachIndexed { i, child -> validate(child, "$path.$i") }
            JsonNull -> throw SchemaValidationException.UnsupportedValue(path.ifEmpty { "<root>" })
            is JsonPrimitive -> Unit // string / number / bool are fine
        }
    }
}
