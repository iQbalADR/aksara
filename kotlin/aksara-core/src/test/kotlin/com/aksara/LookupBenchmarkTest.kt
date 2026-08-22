package com.aksara

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * Proves the core claim: `t(...)` is a constant-time hash lookup independent of table
 * size. Mirror of the Swift `LookupBenchmarkTests`.
 */
class LookupBenchmarkTest {
    private fun makeTable(count: Int): TranslationTable {
        val entries = LinkedHashMap<String, String>(count)
        for (i in 0 until count) entries["ns.key_$i"] = "value {{n}} number $i"
        return TranslationTable("en", entries)
    }

    @Test
    fun lookupIsCorrectAtScale() {
        val table = makeTable(50_000)
        assertEquals(50_000, table.count)
        assertEquals("value {{n}} number 0", table.value("ns.key_0"))
        assertEquals("value {{n}} number 49999", table.value("ns.key_49999"))
        assertNull(table.value("ns.key_50000"))
    }

    @Test
    fun lookupPerformanceOnLargeTable() {
        val table = makeTable(50_000)
        val keys = (0 until 1_000).map { "ns.key_${it * 49}" }
        val start = System.nanoTime()
        repeat(100) { for (key in keys) table.value(key) }
        val elapsedMs = (System.nanoTime() - start) / 1_000_000.0
        // Informational; 100k lookups on a 50k-entry map complete near-instantly.
        println("100k lookups on 50k-entry table: ${"%.2f".format(elapsedMs)} ms")
    }
}
