package com.aksara

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlin.test.Test
import kotlin.test.assertEquals

class FlattenerTest {
    private fun flatten(json: String): Map<String, String> =
        Flattener.flatten(Json.parseToJsonElement(json).jsonObject)

    @Test
    fun nestedObjectsBecomeDotPaths() {
        val flat = flatten(
            """{"common":{"login":"Log in","nested":{"deep":"value"}},"auth":{"title":"Sign in"}}"""
        )
        assertEquals("Log in", flat["common.login"])
        assertEquals("value", flat["common.nested.deep"])
        assertEquals("Sign in", flat["auth.title"])
    }

    @Test
    fun pluralSubKeysAreFlattened() {
        val flat = flatten("""{"items":{"one":"1 item","other":"{{count}} items"}}""")
        assertEquals("1 item", flat["items.one"])
        assertEquals("{{count}} items", flat["items.other"])
    }

    @Test
    fun arraysAreIndexed() {
        val flat = flatten("""{"steps":["first","second","third"]}""")
        assertEquals("first", flat["steps.0"])
        assertEquals("second", flat["steps.1"])
        assertEquals("third", flat["steps.2"])
    }

    @Test
    fun numbersAndBoolsAreStringified() {
        val flat = flatten("""{"count":42,"enabled":true}""")
        assertEquals("42", flat["count"])
        assertEquals("true", flat["enabled"])
    }
}
