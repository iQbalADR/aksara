package com.aksara

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Thrown on a non-success HTTP status. Any failure means "keep last-good". */
class OtaException(message: String) : Exception(message)

/** The result of a single conditional fetch. Mirror of the Swift `FetchOutcome`. */
sealed interface FetchOutcome {
    /** Server replied `304 Not Modified` — the cached ETag is still current. */
    object NotModified : FetchOutcome

    /** A fresh payload, plus its new ETag (if the server sent one). */
    class Updated(val data: ByteArray, val etag: String?) : FetchOutcome
}

/**
 * Abstraction over "GET the bundle for a language, conditionally". The default
 * implementation uses [HttpURLConnection] with certificate pinning; tests inject a
 * mock. Mirror of the Swift `RemoteBundleFetcher`.
 */
interface RemoteBundleFetcher {
    suspend fun fetch(url: String, etag: String?): FetchOutcome
}

/**
 * Production fetcher: conditional GET (`If-None-Match`) over a (optionally) pinned
 * TLS connection, off the main thread via [Dispatchers.IO].
 */
class HttpUrlConnectionBundleFetcher(
    private val pinnedCertificateHashes: Set<String> = emptySet(),
) : RemoteBundleFetcher {

    override suspend fun fetch(url: String, etag: String?): FetchOutcome = withContext(Dispatchers.IO) {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            useCaches = false
            connectTimeout = 15_000
            readTimeout = 15_000
            if (etag != null) setRequestProperty("If-None-Match", etag)
        }
        if (connection is HttpsURLConnection && pinnedCertificateHashes.isNotEmpty()) {
            connection.sslSocketFactory = CertificatePinner.socketFactory(pinnedCertificateHashes)
        }
        try {
            connection.connect()
            val code = connection.responseCode
            when {
                code == HttpURLConnection.HTTP_NOT_MODIFIED -> FetchOutcome.NotModified
                code in 200..299 -> {
                    val newEtag = connection.getHeaderField("ETag")
                    val data = connection.inputStream.use { it.readBytes() }
                    FetchOutcome.Updated(data, newEtag)
                }
                else -> throw OtaException("HTTP $code")
            }
        } finally {
            connection.disconnect()
        }
    }
}
