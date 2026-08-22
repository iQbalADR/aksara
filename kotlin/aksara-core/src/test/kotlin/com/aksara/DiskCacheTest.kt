package com.aksara

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull

class DiskCacheTest {
    @Test
    fun saveAndLoadRoundTrip() {
        val cache = DiskCache(TestSupport.makeTempDir())
        val payload = TestSupport.bytes("""{"a":"b"}""")
        cache.saveBundle(payload, etag = "v1", language = "en")

        assertContentEquals(payload, cache.loadBundle("en"))
        assertEquals("v1", cache.loadETag("en"))
    }

    @Test
    fun missingLanguageReturnsNull() {
        val cache = DiskCache(TestSupport.makeTempDir())
        assertNull(cache.loadBundle("fr"))
        assertNull(cache.loadETag("fr"))
    }

    @Test
    fun clearRemovesEntry() {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("{}"), etag = "v1", language = "en")
        cache.clear("en")
        assertNull(cache.loadBundle("en"))
        assertNull(cache.loadETag("en"))
    }

    @Test
    fun languagesAreIsolated() {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("""{"x":"en"}"""), etag = "e", language = "en")
        cache.saveBundle(TestSupport.bytes("""{"x":"id"}"""), etag = "i", language = "id")
        assertEquals("e", cache.loadETag("en"))
        assertEquals("i", cache.loadETag("id"))
    }
}
