package com.aksara.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.aksara.Localizer

/**
 * Compose mirror of the SwiftUI layer (`AksaraSwiftUI`).
 *
 * `locString(...)` collects the core [Localizer.revision] `StateFlow`, so it
 * recomposes automatically on every language switch or OTA swap — no manual refresh.
 *
 * ```kotlin
 * Text(locString("common.welcome", mapOf("name" to "Oncom")))
 * Text(locString("common.items", count = cartCount))
 * Button(onClick = { Localizer.instance.setLanguage("id") }) { Text("Bahasa") }
 * ```
 */
@Composable
public fun locString(
    key: String,
    args: Map<String, Any> = emptyMap(),
    localizer: Localizer = Localizer.instance,
): String {
    val revision by localizer.revision.collectAsState()
    return remember(revision, key, args) { localizer.t(key, args) }
}

/** Plural-aware overload. `{{count}}` is auto-injected. */
@Composable
public fun locString(
    key: String,
    count: Int,
    args: Map<String, Any> = emptyMap(),
    localizer: Localizer = Localizer.instance,
): String {
    val revision by localizer.revision.collectAsState()
    return remember(revision, key, count, args) { localizer.t(key, count, args) }
}
