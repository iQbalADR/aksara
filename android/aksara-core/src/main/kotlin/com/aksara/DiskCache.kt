package com.aksara

import java.io.File

/**
 * Persists the last-good bundle per language (raw bytes as applied).
 *
 * This is a **local warm-start cache**, not a network cache — Aksara does no
 * fetching. On launch the [Localizer] re-parses the cached bytes (with the configured
 * [TranslationParser]) so a returning user sees the last applied translations before
 * the app re-downloads anything. On Android, pass `context.cacheDir` as [directory]
 * (or, if you handle persistence yourself, ignore this entirely).
 */
class DiskCache(directory: File? = null) {
    private val directory: File =
        (directory ?: File(System.getProperty("java.io.tmpdir"), "Aksara")).also { it.mkdirs() }

    private fun bundleFile(language: String) = File(directory, "$language.json")

    fun saveBundle(data: ByteArray, language: String) {
        bundleFile(language).writeBytes(data)
    }

    fun loadBundle(language: String): ByteArray? =
        bundleFile(language).takeIf { it.exists() }?.readBytes()

    fun clear(language: String) {
        bundleFile(language).delete()
    }
}
