package com.aksara

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

class OtaUpdaterTest {
    private val base = "https://cdn.example.com/i18n/"

    @Test
    fun updatedPayloadBuildsTableAndPersistsLastGood() = runTest {
        val cache = DiskCache(TestSupport.makeTempDir())
        val payload = TestSupport.bytes("""{"common":{"welcome":"OTA {{name}}"}}""")
        val fetcher = MockFetcher(listOf(Result.success(FetchOutcome.Updated(payload, "v2"))))
        val updater = OtaUpdater(base, fetcher, cache)

        val (result, table) = updater.checkForUpdates("en")

        assertEquals(UpdateResult.Updated("en"), result)
        assertEquals("OTA {{name}}", table?.value("common.welcome"))
        assertEquals("https://cdn.example.com/i18n/en.json", fetcher.requestedUrls.first())
        assertContentEquals(payload, cache.loadBundle("en"))
        assertEquals("v2", cache.loadETag("en"))
    }

    @Test
    fun storedEtagIsSentOnNextRequest() = runTest {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("{}"), etag = "existing-etag", language = "en")
        val fetcher = MockFetcher(listOf(Result.success(FetchOutcome.NotModified)))
        val updater = OtaUpdater(base, fetcher, cache)

        val (result, table) = updater.checkForUpdates("en")

        assertEquals(UpdateResult.NotModified, result)
        assertNull(table)
        assertEquals("existing-etag", fetcher.sentEtags.first())
    }

    @Test
    fun malformedPayloadFailsAndKeepsLastGood() = runTest {
        val cache = DiskCache(TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.bytes("""{"good":"data"}"""), etag = "v1", language = "en")
        val fetcher = MockFetcher(listOf(Result.success(FetchOutcome.Updated(TestSupport.bytes("garbage {"), "v2"))))
        val updater = OtaUpdater(base, fetcher, cache)

        val (result, table) = updater.checkForUpdates("en")

        assertEquals(UpdateResult.Failed, result)
        assertNull(table)
        // Last-good untouched — the poisoned payload never overwrote it.
        assertContentEquals(TestSupport.bytes("""{"good":"data"}"""), cache.loadBundle("en"))
        assertEquals("v1", cache.loadETag("en"))
    }

    @Test
    fun networkErrorFails() = runTest {
        val cache = DiskCache(TestSupport.makeTempDir())
        val fetcher = MockFetcher(listOf(Result.failure(OtaException("HTTP 500"))))
        val updater = OtaUpdater(base, fetcher, cache)

        val (result, table) = updater.checkForUpdates("en")

        assertEquals(UpdateResult.Failed, result)
        assertNull(table)
        assertNull(cache.loadBundle("en"))
    }
}
