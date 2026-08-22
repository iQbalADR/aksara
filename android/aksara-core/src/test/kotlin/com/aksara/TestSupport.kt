package com.aksara

import java.io.File
import kotlin.io.path.createTempDirectory

/**
 * A scripted [RemoteBundleFetcher] for OTA tests. Records what was requested and
 * returns queued outcomes in order. Mirror of the Swift `MockFetcher`.
 */
class MockFetcher(outcomes: List<Result<FetchOutcome>>) : RemoteBundleFetcher {
    private val queue = ArrayDeque(outcomes)
    val requestedUrls = mutableListOf<String>()
    val sentEtags = mutableListOf<String?>()

    override suspend fun fetch(url: String, etag: String?): FetchOutcome {
        requestedUrls += url
        sentEtags += etag
        val next = queue.removeFirstOrNull() ?: throw OtaException("no more outcomes")
        return next.getOrThrow()
    }
}

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
