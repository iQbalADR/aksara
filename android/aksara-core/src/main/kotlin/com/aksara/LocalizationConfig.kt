package com.aksara

import java.io.File

/**
 * Startup configuration for the [Localizer].
 *
 * Mirrors the Swift `LocalizationConfig` (see `ios/`). Keep the two in sync — any
 * field added here is a PR obligation to add on the other platform.
 *
 * Aksara is **network-agnostic**: there's no remote URL or fetching here. You
 * download bundles however you like and feed them in with [Localizer.applyBundle].
 *
 * @property defaultLanguage Language shown first; its bundled JSON is loaded synchronously at startup.
 * @property fallbackLanguage Used when a key is missing in the active language.
 * @property bundledResource Base name of the bundled default-language resource (informational).
 * @property bundledLoader Loads bundled JSON bytes for a language code. On Android, read from
 *   assets (e.g. `context.assets.open("$code.json")`); in tests, read from the classpath.
 * @property cacheDir Warm-start cache location. On Android pass `context.cacheDir`; defaults to a temp dir.
 *   Bundles passed to [Localizer.applyBundle] are persisted here and re-loaded on next launch.
 * @property parser Turns raw bundle bytes into the flat lookup map. Defaults to [I18nextParser];
 *   inject your own to accept a custom JSON format/model.
 */
class LocalizationConfig(
    val defaultLanguage: String,
    val fallbackLanguage: String,
    val bundledResource: String? = null,
    val bundledLoader: (String) -> ByteArray? = { null },
    val cacheDir: File? = null,
    val parser: TranslationParser = I18nextParser,
)
