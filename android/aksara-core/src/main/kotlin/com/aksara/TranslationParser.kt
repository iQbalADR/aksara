package com.aksara

import kotlinx.serialization.json.JsonObject

/**
 * Turns raw bundle bytes into Aksara's flat lookup map.
 *
 * The returned map is the contract the rest of the runtime relies on:
 * - keys are **dot-paths** (`common.login`);
 * - plural forms are `key.<category>` where `<category>` is a CLDR plural key
 *   (`zero`/`one`/`two`/`few`/`many`/`other`);
 * - values are templates containing `{{var}}` placeholders.
 *
 * Aksara never fetches anything itself — the consumer downloads the bytes however
 * they like and hands them to [Localizer.applyBundle]. Inject a custom parser via
 * [LocalizationConfig.parser] to accept **any** on-the-wire JSON shape (your own
 * model); the built-in [I18nextParser] reads nested i18next JSON.
 */
fun interface TranslationParser {
    /**
     * Parse [data] (the raw bundle for [language]) into the flat lookup map.
     * Throw to reject a malformed payload — the caller keeps the current table.
     */
    fun parse(data: ByteArray, language: String): Map<String, String>
}

/**
 * Default parser: nested i18next-style JSON → flat dot-path map.
 *
 * Validates the payload (rejecting non-object roots and `null` leaves), strips the
 * reserved `_version` meta key, then flattens nested objects/arrays — plural
 * categories are ordinary nested keys (`items.one`, `items.other`).
 */
object I18nextParser : TranslationParser {
    override fun parse(data: ByteArray, language: String): Map<String, String> {
        val json = SchemaValidator.validated(data)
        val mutable = json.toMutableMap()
        mutable.remove("_version") // reserved meta key, not a translation
        return Flattener.flatten(JsonObject(mutable))
    }
}
