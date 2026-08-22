package com.aksara

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Outcome of an OTA check, returned by [Localizer.checkForUpdates].
 * Mirror of the Swift `UpdateResult`.
 */
sealed interface UpdateResult {
    /** A new bundle was fetched, validated, cached, and (by the caller) swapped in. */
    data class Updated(val language: String) : UpdateResult

    /** Server said nothing changed (`304`) — current table kept. */
    object NotModified : UpdateResult

    /** No remote configured — nothing to do. */
    object Skipped : UpdateResult

    /** Network failure or malformed payload — last-good table kept. */
    object Failed : UpdateResult
}

/**
 * The OTA state machine: conditional fetch -> schema-validate -> build immutable
 * table -> persist last-good. It never touches the live table; it hands the built
 * table back to the [Localizer], which owns the atomic swap.
 *
 * Kept free of the HTTP client and UI concerns so it's unit-testable with a mock
 * [RemoteBundleFetcher] and a temp [DiskCache]. Mirror of the Swift `OTAUpdater`.
 */
internal class OtaUpdater(
    private val remoteBaseUrl: String,
    private val fetcher: RemoteBundleFetcher,
    private val cache: DiskCache,
) {
    suspend fun checkForUpdates(language: String): Pair<UpdateResult, TranslationTable?> {
        val url = joinUrl(remoteBaseUrl, "$language.json")
        val etag = cache.loadETag(language)

        return try {
            when (val outcome = fetcher.fetch(url, etag)) {
                is FetchOutcome.NotModified -> UpdateResult.NotModified to null
                is FetchOutcome.Updated -> {
                    // Validate + build BEFORE anything is persisted or swapped.
                    val table = withContext(Dispatchers.Default) {
                        TranslationTable.make(language, outcome.data)
                    }
                    cache.saveBundle(outcome.data, outcome.etag, language) // only now "last-good"
                    UpdateResult.Updated(language) to table
                }
            }
        } catch (e: Exception) {
            // Network error or schema rejection — keep whatever we already have.
            UpdateResult.Failed to null
        }
    }

    private fun joinUrl(base: String, path: String): String =
        if (base.endsWith("/")) base + path else "$base/$path"
}
