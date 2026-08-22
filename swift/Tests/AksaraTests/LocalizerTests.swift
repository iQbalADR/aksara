import XCTest
@testable import Aksara

final class LocalizerTests: XCTestCase {
    /// Fresh Localizer per test (never the shared singleton) so state can't leak.
    private func makeLocalizer(
        default defaultLanguage: String = "en",
        fallback fallbackLanguage: String = "en",
        remoteURL: URL? = nil,
        fetcher: RemoteBundleFetcher? = nil
    ) -> Localizer {
        let loc = Localizer()
        let config = LocalizationConfig(
            defaultLanguage: defaultLanguage,
            fallbackLanguage: fallbackLanguage,
            bundledResource: defaultLanguage,
            remoteURL: remoteURL,
            bundle: .module,
            cacheDirectory: TestSupport.makeTempDir()
        )
        loc.configure(config, fetcherOverride: fetcher)
        return loc
    }

    // MARK: Lookup + interpolation

    func testSimpleLookup() {
        let loc = makeLocalizer()
        XCTAssertEqual(loc.t("auth.login"), "Log in")
    }

    func testInterpolation() {
        let loc = makeLocalizer()
        XCTAssertEqual(loc.t("common.welcome", args: ["name": "Oncom"]), "Welcome, Oncom!")
    }

    func testInterpolationLeavesMissingVarVisible() {
        let loc = makeLocalizer()
        XCTAssertEqual(
            loc.t("common.greeting", args: ["name": "Sam"]),
            "Hello Sam, you have {{unread}} messages"
        )
    }

    // MARK: Plurals

    func testEnglishPlurals() {
        let loc = makeLocalizer()
        XCTAssertEqual(loc.t("common.items", count: 1), "1 item")
        XCTAssertEqual(loc.t("common.items", count: 5), "5 items")
    }

    func testArabicPlurals() {
        let loc = makeLocalizer(default: "ar", fallback: "en")
        XCTAssertEqual(loc.t("common.apples", count: 0), "لا تفاحات")
        XCTAssertEqual(loc.t("common.apples", count: 1), "تفاحة واحدة")
        XCTAssertEqual(loc.t("common.apples", count: 2), "تفاحتان")
        XCTAssertEqual(loc.t("common.apples", count: 3), "3 تفاحات")
        XCTAssertEqual(loc.t("common.apples", count: 11), "11 تفاحة")
        XCTAssertEqual(loc.t("common.apples", count: 100), "100 تفاحة")
    }

    func testPluralFallsBackToOtherWhenCategoryMissing() {
        // Indonesian bundle only defines `other`; count 1 (which would be `one`
        // in English) must still resolve via the `other` fallback.
        let loc = makeLocalizer(default: "id", fallback: "en")
        XCTAssertEqual(loc.t("common.items", count: 1), "1 barang")
    }

    // MARK: Fallback chain

    func testFallsBackToFallbackLanguage() {
        let loc = makeLocalizer(default: "id", fallback: "en")
        // `english_only` and `auth.biometric_prompt` exist only in en.json.
        XCTAssertEqual(loc.t("common.english_only"), "This key exists only in English")
        XCTAssertEqual(loc.t("auth.biometric_prompt"), "Authenticate with Face ID")
    }

    func testUnknownKeyReturnsKeyItself() {
        let loc = makeLocalizer()
        XCTAssertEqual(loc.t("does.not.exist"), "does.not.exist")
    }

    // MARK: Language switching

    func testSetLanguageSwitchesActiveTable() {
        let loc = makeLocalizer(default: "en", fallback: "en")
        XCTAssertEqual(loc.currentLanguage, "en")
        XCTAssertEqual(loc.t("auth.login"), "Log in")

        loc.setLanguage("id")
        XCTAssertEqual(loc.currentLanguage, "id")
        XCTAssertEqual(loc.t("auth.login"), "Masuk")
    }

    func testSetLanguageToUnavailableLanguageIsNoOp() {
        let loc = makeLocalizer(default: "en", fallback: "en")
        loc.setLanguage("de") // no de.json bundled
        XCTAssertEqual(loc.currentLanguage, "en")
        XCTAssertEqual(loc.t("auth.login"), "Log in")
    }

    func testChangePostsNotification() {
        let loc = makeLocalizer(default: "en", fallback: "en")
        let expectation = XCTNSNotificationExpectation(name: .aksaraDidChange, object: loc)
        loc.setLanguage("id")
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: OTA end-to-end (through Localizer, mock fetcher)

    func testCheckForUpdatesSwapsTableLive() async {
        let base = URL(string: "https://cdn.example.com/i18n/")!
        let payload = TestSupport.data(#"{"auth":{"login":"Signed in (OTA)"}}"#)
        let fetcher = MockFetcher([.success(.updated(data: payload, etag: "v9"))])
        let loc = makeLocalizer(default: "en", fallback: "en", remoteURL: base, fetcher: fetcher)

        XCTAssertEqual(loc.t("auth.login"), "Log in")
        let result = await loc.checkForUpdates()
        XCTAssertEqual(result, .updated(language: "en"))
        XCTAssertEqual(loc.t("auth.login"), "Signed in (OTA)")
    }

    func testCheckForUpdatesFailureKeepsLastGood() async {
        let base = URL(string: "https://cdn.example.com/i18n/")!
        let fetcher = MockFetcher([.failure(OTAError.httpStatus(503))])
        let loc = makeLocalizer(default: "en", fallback: "en", remoteURL: base, fetcher: fetcher)

        let result = await loc.checkForUpdates()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(loc.t("auth.login"), "Log in") // unchanged
    }

    func testCheckForUpdatesSkippedWithoutRemote() async {
        let loc = makeLocalizer() // no remoteURL
        let result = await loc.checkForUpdates()
        XCTAssertEqual(result, .skipped)
    }

    func testCachedRemoteBundlePreferredOverBundledOnConfigure() {
        // Pre-seed the cache as if a previous OTA landed, then configure fresh.
        let tempDir = TestSupport.makeTempDir()
        let cache = DiskCache(directory: tempDir)
        cache.saveBundle(TestSupport.data(#"{"auth":{"login":"From cache"}}"#), etag: "v1", language: "en")

        let loc = Localizer()
        loc.configure(LocalizationConfig(
            defaultLanguage: "en",
            fallbackLanguage: "en",
            bundle: .module,
            cacheDirectory: tempDir
        ))
        XCTAssertEqual(loc.t("auth.login"), "From cache")
    }
}
