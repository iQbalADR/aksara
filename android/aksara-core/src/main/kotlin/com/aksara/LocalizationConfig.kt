package com.aksara

import java.io.File

/**
 * Startup configuration for the [Localizer].
 *
 * Mirrors the Swift `LocalizationConfig`. Keep the two in sync — any field added here
 * is a PR obligation to add on the other platform.
 *
 * @property defaultLanguage Language shown first; its bundled JSON is loaded synchronously at startup.
 * @property fallbackLanguage Used when a key is missing in the active language.
 * @property bundledResource Base name of the bundled default-language resource (informational).
 * @property remoteUrl Base URL of the OTA endpoint; per-language files live at `<remoteUrl>/<code>.json`.
 * @property bundledLoader Loads bundled JSON bytes for a language code. On Android, read from
 *   assets (e.g. `context.assets.open("$code.json")`); in tests, read from the classpath.
 * @property pinnedCertificateHashes `base64(SHA-256(DER cert))` pins for the OTA endpoint. Empty = no pinning.
 * @property cacheDir Disk-cache location. On Android pass `context.cacheDir`; defaults to a temp dir.
 */
class LocalizationConfig(
    val defaultLanguage: String,
    val fallbackLanguage: String,
    val bundledResource: String? = null,
    val remoteUrl: String? = null,
    val bundledLoader: (String) -> ByteArray? = { null },
    val pinnedCertificateHashes: Set<String> = emptySet(),
    val cacheDir: File? = null,
)
