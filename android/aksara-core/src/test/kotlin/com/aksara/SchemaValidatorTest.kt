package com.aksara

import kotlinx.serialization.json.JsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue

class SchemaValidatorTest {
    @Test
    fun validObjectPasses() {
        val dict = SchemaValidator.validated(TestSupport.bytes("""{"common":{"login":"Log in"}}"""))
        val common = dict["common"] as JsonObject
        assertTrue(common.containsKey("login"))
    }

    @Test
    fun numbersAllowedAsLeaves() {
        SchemaValidator.validated(TestSupport.bytes("""{"n":42}""")) // no throw
    }

    @Test
    fun topLevelArrayRejected() {
        assertFailsWith<SchemaValidationException.TopLevelNotObject> {
            SchemaValidator.validated(TestSupport.bytes("[1,2,3]"))
        }
    }

    @Test
    fun invalidJsonRejected() {
        assertFailsWith<SchemaValidationException.NotJson> {
            SchemaValidator.validated(TestSupport.bytes("not json at all"))
        }
    }

    @Test
    fun nullLeafRejected() {
        val error = assertFailsWith<SchemaValidationException.UnsupportedValue> {
            SchemaValidator.validated(TestSupport.bytes("""{"a":{"b":null}}"""))
        }
        assertEquals("a.b", error.path)
    }
}
