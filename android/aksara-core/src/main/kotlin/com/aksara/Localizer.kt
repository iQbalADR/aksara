package com.aksara

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.concurrent.atomic.AtomicReference

/**
 * The runtime entry point. Loads translations, resolves keys in O(1), and swaps in
 * new tables atomically for language switches and consumer-supplied bundle updates.
 *
 * Public API is mirrored 1:1 with the Swift `Localizer`.
 *
 * **Network-agnostic:** Aksara never downloads anything. You fetch bundles however you
 * like (OkHttp, Ktor, Retrofit, a CDN SDK, a file…) and hand the bytes to [applyBundle].
 * How those bytes are parsed is pluggable too — see [TranslationParser].
 *
 * Threading: [t] is synchronous and safe on the main thread — it reads a single
 * immutable snapshot via an [AtomicReference] and does one map lookup. Bundled
 * languages load synchronously at [configure]. [applyBundle] parses on the calling
 * thread; the [update] helper runs it inside a coroutine.
 *
 * Live UI: [revision] increments on every table swap. The Compose layer collects it
 * so `locString(...)` recomposes automatically (mirror of the SwiftUI `revision`).
 */
class Localizer(private val plurals: PluralResolver = PluralResolver.default) {

    private data class State(
        val active: TranslationTable?,
        val fallback: TranslationTable?,
        val language: String,
    )

    private val state = AtomicReference(State(active = null, fallback = null, language = "en"))
    private val _revision = MutableStateFlow(0)

    /** Bumped on every table swap; observe it to re-apply localized text live. */
    val revision: StateFlow<Int> get() = _revision.asStateFlow()

    private var config: LocalizationConfig? = null
    private var cache: DiskCache? = null

    // MARK: Configuration

    /** Configure and perform the synchronous first load. Call once at startup. */
    fun configure(config: LocalizationConfig) {
        val cache = DiskCache(config.cacheDir)
        this.config = config
        this.cache = cache

        // 1) Synchronous bundled load — first render must not wait on disk/network.
        val defaultTable = loadBundledTable(config.defaultLanguage, config)
        val fallbackTable = if (config.fallbackLanguage == config.defaultLanguage) {
            defaultTable
        } else {
            loadBundledTable(config.fallbackLanguage, config)
        }
        state.set(State(active = defaultTable, fallback = fallbackTable, language = config.defaultLanguage))

        // 2) Prefer a last-good cached bundle (from a previous applyBundle) over the
        //    bundled default, if present and still parseable with the current parser.
        cache.loadBundle(config.defaultLanguage)?.let { cached ->
            runCatching { config.parser.parse(cached, config.defaultLanguage) }
                .getOrNull()
                ?.let { swapActive(TranslationTable(config.defaultLanguage, it), config.defaultLanguage) }
        }
    }

    // MARK: Lookup

    /** Resolve [key], interpolating `{{var}}` placeholders from [args]. */
    fun t(key: String, args: Map<String, Any> = emptyMap()): String =
        resolve(key, category = null, args = stringify(args))

    /** Resolve a plural [key] for [count]. `{{count}}` is auto-injected into [args]. */
    fun t(key: String, count: Int, args: Map<String, Any> = emptyMap()): String {
        val language = state.get().language
        val category = plurals.category(count, language)
        val merged = stringify(args).toMutableMap()
        merged.putIfAbsent("count", count.toString())
        return resolve(key, category, merged)
    }

    private fun resolve(key: String, category: PluralCategory?, args: Map<String, String>): String {
        val snapshot = state.get()

        val candidates = when (category) {
            null -> listOf(key)
            PluralCategory.OTHER -> listOf("$key.other")
            else -> listOf("$key.${category.key}", "$key.other")
        }

        // Fallback chain: active language -> fallback language -> the raw key itself.
        firstMatch(candidates, snapshot.active)?.let { return Interpolator.interpolate(it, args) }
        firstMatch(candidates, snapshot.fallback)?.let { return Interpolator.interpolate(it, args) }
        return key
    }

    private fun firstMatch(keys: List<String>, table: TranslationTable?): String? {
        if (table == null) return null
        for (key in keys) table.value(key)?.let { return it }
        return null
    }

    // MARK: Language switching

    /**
     * Switch the active language and trigger a live UI update. No-op if no bundle
     * (cached or bundled) is available for [language].
     */
    fun setLanguage(language: String) {
        val config = this.config ?: return
        val table = cache?.loadBundle(language)?.let { cached ->
            runCatching { TranslationTable(language, config.parser.parse(cached, language)) }.getOrNull()
        } ?: loadBundledTable(language, config) ?: return // keep current — never blank the UI
        swapActive(table, language)
    }

    // MARK: Applying consumer-fetched bundles

    /**
     * Feed a freshly-downloaded bundle into the runtime. **You** fetch the bytes (any
     * transport, any auth); Aksara parses, validates, and swaps.
     *
     * - The configured [TranslationParser] parses [data]. If it throws, the current
     *   table is kept (last-good) and the exception propagates.
     * - On success the bytes are persisted to the warm-start cache for [language].
     * - If [language] is the active or fallback language, the visible table is swapped
     *   and observers are notified. Otherwise it's cached for a later [setLanguage].
     *
     * @throws IllegalStateException if called before [configure]; parser exceptions propagate.
     */
    fun applyBundle(data: ByteArray, language: String) {
        val config = this.config
            ?: throw IllegalStateException("Aksara: configure(...) must be called before applyBundle(...)")

        // Parse first — a bad payload must never replace last-good.
        val entries = config.parser.parse(data, language)
        cache?.saveBundle(data, language)

        val table = TranslationTable(language, entries)
        var changed = false
        state.updateAndGet { s ->
            var next = s
            if (language == s.language) { next = next.copy(active = table); changed = true }
            if (language == config.fallbackLanguage) { next = next.copy(fallback = table); changed = true }
            next
        }
        if (changed) _revision.update { it + 1 }
    }

    /**
     * Convenience: run your own suspending [fetch] for [language], then apply the
     * result. Aksara stays agnostic — [fetch] is entirely yours.
     *
     * ```kotlin
     * loc.update("id") { lang -> myClient.download("https://cdn.example.com/i18n/$lang.json") }
     * ```
     */
    suspend fun update(language: String, fetch: suspend (String) -> ByteArray) {
        applyBundle(fetch(language), language)
    }

    // MARK: Introspection

    val currentLanguage: String get() = state.get().language

    /** Number of keys in the active table (handy for smoke tests / benchmarks). */
    val activeKeyCount: Int get() = state.get().active?.count ?: 0

    // MARK: Internals

    /** The atomic swap: replace the single immutable reference, then broadcast. */
    private fun swapActive(table: TranslationTable, language: String) {
        state.updateAndGet { it.copy(active = table, language = language) }
        _revision.update { it + 1 }
    }

    private fun loadBundledTable(language: String, config: LocalizationConfig): TranslationTable? {
        val bytes = config.bundledLoader(language) ?: return null
        return runCatching { TranslationTable(language, config.parser.parse(bytes, language)) }.getOrNull()
    }

    private fun stringify(args: Map<String, Any>): Map<String, String> {
        if (args.isEmpty()) return emptyMap()
        return args.mapValues { (_, value) -> value.toString() }
    }

    companion object {
        /** Shared instance used by the Compose layer. You may also create your own. */
        val instance: Localizer by lazy { Localizer() }
    }
}
