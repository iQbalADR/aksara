package com.aksara

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertNull

class DiskCacheTest {
    @Test
    fun saveAndLoadRoundTrip() {
        val cache = DiskCache(TestSupport.makeTempDir())
        val payload = TestSupport.bytes("""{"a":"b"}""")
        cache.saveBundle(payload, "en")

        assertContentEquals(payload, cache.loadBundle("en"))
    }

    @Test
    fun missingLanguageReturnsNull() {
        val cache = DiskCache(TestSupport.makeTempDir())
        assertNull(cache.loadBundle("fr"))
    }

    @Test
    fun clearRemovesEntry() {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("{}"), "en")
        cache.clear("en")
        assertNull(cache.loadBundle("en"))
    }

    @Test
    fun languagesAreIsolated() {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("""{"x":"en"}"""), "en")
        cache.saveBundle(TestSupport.bytes("""{"x":"id"}"""), "id")
        assertContentEquals(TestSupport.bytes("""{"x":"en"}"""), cache.loadBundle("en"))
        assertContentEquals(TestSupport.bytes("""{"x":"id"}"""), cache.loadBundle("id"))
    }
}
