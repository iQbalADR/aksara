package com.aksara

import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

class LocalizerTest {
    /** Fresh Localizer per test (never the shared singleton) so state can't leak. */
    private fun makeLocalizer(
        default: String = "en",
        fallback: String = "en",
        remoteUrl: String? = null,
        fetcher: RemoteBundleFetcher? = null,
    ): Localizer {
        val loc = Localizer()
        loc.configure(
            LocalizationConfig(
                defaultLanguage = default,
                fallbackLanguage = fallback,
                bundledResource = default,
                remoteUrl = remoteUrl,
                bundledLoader = TestSupport.classpathLoader(),
                cacheDir = TestSupport.makeTempDir(),
            ),
            fetcherOverride = fetcher,
        )
        return loc
    }

    // Lookup + interpolation

    @Test
    fun simpleLookup() {
        assertEquals("Log in", makeLocalizer().t("auth.login"))
    }

    @Test
    fun interpolation() {
        assertEquals("Welcome, Oncom!", makeLocalizer().t("common.welcome", mapOf("name" to "Oncom")))
    }

    @Test
    fun interpolationLeavesMissingVarVisible() {
        assertEquals(
            "Hello Sam, you have {{unread}} messages",
            makeLocalizer().t("common.greeting", mapOf("name" to "Sam"))
        )
    }

    // Plurals

    @Test
    fun englishPlurals() {
        val loc = makeLocalizer()
        assertEquals("1 item", loc.t("common.items", count = 1))
        assertEquals("5 items", loc.t("common.items", count = 5))
    }

    @Test
    fun arabicPlurals() {
        val loc = makeLocalizer(default = "ar", fallback = "en")
        assertEquals("لا تفاحات", loc.t("common.apples", count = 0))
        assertEquals("تفاحة واحدة", loc.t("common.apples", count = 1))
        assertEquals("تفاحتان", loc.t("common.apples", count = 2))
        assertEquals("3 تفاحات", loc.t("common.apples", count = 3))
        assertEquals("11 تفاحة", loc.t("common.apples", count = 11))
        assertEquals("100 تفاحة", loc.t("common.apples", count = 100))
    }

    @Test
    fun pluralFallsBackToOtherWhenCategoryMissing() {
        // Indonesian bundle only defines `other`; count 1 must still resolve via it.
        val loc = makeLocalizer(default = "id", fallback = "en")
        assertEquals("1 barang", loc.t("common.items", count = 1))
    }

    // Fallback chain

    @Test
    fun fallsBackToFallbackLanguage() {
        val loc = makeLocalizer(default = "id", fallback = "en")
        assertEquals("This key exists only in English", loc.t("common.english_only"))
        assertEquals("Authenticate with Face ID", loc.t("auth.biometric_prompt"))
    }

    @Test
    fun unknownKeyReturnsKeyItself() {
        assertEquals("does.not.exist", makeLocalizer().t("does.not.exist"))
    }

    // Language switching + live updates

    @Test
    fun setLanguageSwitchesActiveTable() {
        val loc = makeLocalizer(default = "en", fallback = "en")
        assertEquals("en", loc.currentLanguage)
        assertEquals("Log in", loc.t("auth.login"))

        loc.setLanguage("id")
        assertEquals("id", loc.currentLanguage)
        assertEquals("Masuk", loc.t("auth.login"))
    }

    @Test
    fun setLanguageToUnavailableLanguageIsNoOp() {
        val loc = makeLocalizer(default = "en", fallback = "en")
        loc.setLanguage("de") // no de.json bundled
        assertEquals("en", loc.currentLanguage)
        assertEquals("Log in", loc.t("auth.login"))
    }

    @Test
    fun changeBumpsRevision() {
        val loc = makeLocalizer(default = "en", fallback = "en")
        val before = loc.revision.value
        loc.setLanguage("id")
        assertEquals(before + 1, loc.revision.value)
    }

    // OTA end-to-end (through Localizer, mock fetcher)

    @Test
    fun checkForUpdatesSwapsTableLive() = runTest {
        val payload = TestSupport.bytes("""{"auth":{"login":"Signed in (OTA)"}}""")
        val fetcher = MockFetcher(listOf(Result.success(FetchOutcome.Updated(payload, "v9"))))
        val loc = makeLocalizer(default = "en", fallback = "en", remoteUrl = "https://cdn.example.com/i18n/", fetcher = fetcher)

        assertEquals("Log in", loc.t("auth.login"))
        val result = loc.checkForUpdates()
        assertEquals(UpdateResult.Updated("en"), result)
        assertEquals("Signed in (OTA)", loc.t("auth.login"))
    }

    @Test
    fun checkForUpdatesFailureKeepsLastGood() = runTest {
        val fetcher = MockFetcher(listOf(Result.failure(OtaException("HTTP 503"))))
        val loc = makeLocalizer(default = "en", fallback = "en", remoteUrl = "https://cdn.example.com/i18n/", fetcher = fetcher)

        assertEquals(UpdateResult.Failed, loc.checkForUpdates())
        assertEquals("Log in", loc.t("auth.login")) // unchanged
    }

    @Test
    fun checkForUpdatesSkippedWithoutRemote() = runTest {
        assertEquals(UpdateResult.Skipped, makeLocalizer().checkForUpdates())
    }

    @Test
    fun cachedRemoteBundlePreferredOverBundledOnConfigure() {
        val tempDir = TestSupport.makeTempDir()
        DiskCache(tempDir).saveBundle(
            TestSupport.bytes("""{"auth":{"login":"From cache"}}"""), etag = "v1", language = "en"
        )

        val loc = Localizer()
        loc.configure(
            LocalizationConfig(
                defaultLanguage = "en",
                fallbackLanguage = "en",
                bundledLoader = TestSupport.classpathLoader(),
                cacheDir = tempDir,
            )
        )
        assertEquals("From cache", loc.t("auth.login"))
    }
}
