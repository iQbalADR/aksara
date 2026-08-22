package com.aksara

import kotlin.test.Test
import kotlin.test.assertEquals

class PluralResolverTest {
    private val resolver = PluralResolver.default

    @Test
    fun english() {
        assertEquals(PluralCategory.ONE, resolver.category(1, "en"))
        assertEquals(PluralCategory.OTHER, resolver.category(0, "en"))
        assertEquals(PluralCategory.OTHER, resolver.category(2, "en"))
        assertEquals(PluralCategory.OTHER, resolver.category(100, "en"))
    }

    @Test
    fun indonesianAndJapaneseAreOtherOnly() {
        for (count in listOf(0, 1, 2, 5, 100)) {
            assertEquals(PluralCategory.OTHER, resolver.category(count, "id"))
            assertEquals(PluralCategory.OTHER, resolver.category(count, "ja"))
        }
    }

    @Test
    fun arabicFullSet() {
        assertEquals(PluralCategory.ZERO, resolver.category(0, "ar"))
        assertEquals(PluralCategory.ONE, resolver.category(1, "ar"))
        assertEquals(PluralCategory.TWO, resolver.category(2, "ar"))
        assertEquals(PluralCategory.FEW, resolver.category(3, "ar"))
        assertEquals(PluralCategory.FEW, resolver.category(10, "ar"))
        assertEquals(PluralCategory.MANY, resolver.category(11, "ar"))
        assertEquals(PluralCategory.MANY, resolver.category(99, "ar"))
        assertEquals(PluralCategory.OTHER, resolver.category(100, "ar"))
        assertEquals(PluralCategory.FEW, resolver.category(103, "ar")) // 103 % 100 == 3
    }

    @Test
    fun regionCodeIsNormalized() {
        assertEquals(PluralCategory.ONE, resolver.category(1, "en-US"))
        assertEquals(PluralCategory.FEW, resolver.category(3, "ar_EG"))
    }

    @Test
    fun unknownLanguageFallsBackToEnglishRule() {
        assertEquals(PluralCategory.ONE, resolver.category(1, "xx"))
        assertEquals(PluralCategory.OTHER, resolver.category(5, "xx"))
    }

    @Test
    fun customRuleCanBeRegistered() {
        val custom = PluralResolver()
        custom.register(object : PluralRule {
            override fun category(count: Int) = PluralCategory.ZERO
        }, "zz")
        assertEquals(PluralCategory.ZERO, custom.category(7, "zz"))
    }
}
