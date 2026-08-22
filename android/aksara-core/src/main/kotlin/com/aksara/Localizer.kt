package com.aksara

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import java.util.concurrent.atomic.AtomicReference

/**
 * The runtime entry point. Loads translations, resolves keys in O(1), and swaps in
 * new tables atomically for language switches and OTA updates.
 *
 * Public API is mirrored 1:1 with the Swift `Localizer`.
 *
 * Threading: [t] is synchronous and safe to call from the main thread — it reads a
 * single immutable snapshot via an [AtomicReference] and does one map lookup. Bundled
 * languages load synchronously (they're small — first render must not wait). Remote
 * updates fetch and parse off-main via coroutines, then publish the finished table.
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
    private var updater: OtaUpdater? = null

    // MARK: Configuration

    /** Configure and perform the synchronous first load. Call once at startup. */
    fun configure(config: LocalizationConfig) = configure(config, fetcherOverride = null)

    /** Internal seam so tests can inject a mock [RemoteBundleFetcher]. */
    internal fun configure(config: LocalizationConfig, fetcherOverride: RemoteBundleFetcher?) {
        val cache = DiskCache(config.cacheDir)
        this.config = config
        this.cache = cache
        this.updater = config.remoteUrl?.let { remote ->
            val fetcher = fetcherOverride ?: HttpUrlConnectionBundleFetcher(config.pinnedCertificateHashes)
            OtaUpdater(remote, fetcher, cache)
        }

        // 1) Synchronous bundled load — first render must not wait on disk/network.
        val defaultTable = loadBundledTable(config.defaultLanguage, config)
        val fallbackTable = if (config.fallbackLanguage == config.defaultLanguage) {
            defaultTable
        } else {
            loadBundledTable(config.fallbackLanguage, config)
        }
        state.set(State(active = defaultTable, fallback = fallbackTable, language = config.defaultLanguage))

        // 2) Prefer a last-good cached remote bundle over the bundled default, if present.
        cache.loadBundle(config.defaultLanguage)?.let { cached ->
            runCatching { TranslationTable.make(config.defaultLanguage, cached) }
                .getOrNull()
                ?.let { swapActive(it, config.defaultLanguage) }
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
        val table = cache?.loadBundle(language)?.let {
            runCatching { TranslationTable.make(language, it) }.getOrNull()
        } ?: loadBundledTable(language, config) ?: return // keep current — never blank the UI
        swapActive(table, language)
    }

    // MARK: OTA

    /**
     * Fetch a newer bundle for the active language and atomically swap it in. Keeps
     * last-good on any failure. Returns [UpdateResult.Skipped] if no remote is set.
     */
    suspend fun checkForUpdates(): UpdateResult {
        val updater = this.updater ?: return UpdateResult.Skipped
        val language = state.get().language
        val (result, table) = updater.checkForUpdates(language)
        if (result is UpdateResult.Updated && table != null) swapActive(table, language)
        return result
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
        return runCatching { TranslationTable.make(language, bytes) }.getOrNull()
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
