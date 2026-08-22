package com.aksara

import kotlin.test.Test
import kotlin.test.assertEquals

class InterpolatorTest {
    @Test
    fun singleVariable() {
        assertEquals("Welcome, Oncom!", Interpolator.interpolate("Welcome, {{name}}!", mapOf("name" to "Oncom")))
    }

    @Test
    fun multipleVariables() {
        assertEquals(
            "1 + 2 = 3",
            Interpolator.interpolate("{{a}} + {{b}} = {{c}}", mapOf("a" to "1", "b" to "2", "c" to "3"))
        )
    }

    @Test
    fun whitespaceInsideBracesIsTolerated() {
        assertEquals("Hi Sam", Interpolator.interpolate("Hi {{ name }}", mapOf("name" to "Sam")))
    }

    @Test
    fun missingVariableLeavesPlaceholderIntact() {
        assertEquals(
            "Hi Sam, {{missing}}",
            Interpolator.interpolate("Hi {{name}}, {{missing}}", mapOf("name" to "Sam"))
        )
    }

    @Test
    fun noPlaceholdersReturnedUnchanged() {
        assertEquals("plain text", Interpolator.interpolate("plain text", mapOf("x" to "y")))
    }

    @Test
    fun emptyArgsReturnsTemplateUnchanged() {
        assertEquals("Hi {{name}}", Interpolator.interpolate("Hi {{name}}", emptyMap()))
    }

    @Test
    fun unterminatedPlaceholderEmittedVerbatim() {
        assertEquals("Hi {{name", Interpolator.interpolate("Hi {{name", mapOf("name" to "Sam")))
    }
}
