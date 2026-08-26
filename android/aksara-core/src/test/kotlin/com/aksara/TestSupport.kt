package com.aksara

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.io.path.createTempDirectory

object TestSupport {
    /** A throwaway directory unique per call — keeps each test's disk cache isolated. */
    fun makeTempDir(): File = createTempDirectory("AksaraTests").toFile()

    /** Loads bundled test JSON (`en.json`, ...) from the test classpath. */
    fun classpathLoader(): (String) -> ByteArray? = { language ->
        TestSupport::class.java.classLoader
            ?.getResourceAsStream("$language.json")
            ?.use { it.readBytes() }
    }

    fun bytes(json: String): ByteArray = json.toByteArray()
}

/**
 * A custom parser for a non-i18next format: `{"items":[{"id":"a.b","text":"…"}]}`.
 * Demonstrates injecting a consumer-defined JSON model via [LocalizationConfig.parser].
 */
class ListParser : TranslationParser {
    override fun parse(data: ByteArray, language: String): Map<String, String> {
        val items = Json.parseToJsonElement(data.decodeToString()).jsonObject["items"]!!.jsonArray
        return items.associate { item ->
            val obj = item.jsonObject
            obj["id"]!!.jsonPrimitive.content to obj["text"]!!.jsonPrimitive.content
        }
    }
}
