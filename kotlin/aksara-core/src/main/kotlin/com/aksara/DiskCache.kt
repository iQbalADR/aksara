package com.aksara

import java.io.File

/**
 * Persists the last-good remote bundle (and its ETag) per language.
 *
 * On launch the [Localizer] loads the cached bundle — if any — **before** hitting the
 * network, so a returning user sees the latest translations offline and the first
 * render never waits on a request.
 *
 * On Android, pass `context.cacheDir` (or a subdirectory of it) as [directory].
 * Mirror of the Swift `DiskCache`.
 */
class DiskCache(directory: File? = null) {
    private val directory: File =
        (directory ?: File(System.getProperty("java.io.tmpdir"), "Aksara")).also { it.mkdirs() }

    private fun bundleFile(language: String) = File(directory, "$language.json")
    private fun etagFile(language: String) = File(directory, "$language.etag")

    fun saveBundle(data: ByteArray, etag: String?, language: String) {
        bundleFile(language).writeBytes(data)
        if (etag != null) etagFile(language).writeText(etag)
    }

    fun loadBundle(language: String): ByteArray? =
        bundleFile(language).takeIf { it.exists() }?.readBytes()

    fun loadETag(language: String): String? =
        etagFile(language).takeIf { it.exists() }?.readText()

    fun clear(language: String) {
        bundleFile(language).delete()
        etagFile(language).delete()
    }
}
