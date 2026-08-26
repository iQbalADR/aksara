import XCTest
@testable import Aksara

final class LocalizerTests: XCTestCase {
    /// Fresh Localizer per test (never the shared singleton) so state can't leak.
    private func makeLocalizer(
        default defaultLanguage: String = "en",
        fallback fallbackLanguage: String = "en",
        parser: TranslationParser = I18nextParser()
    ) -> Localizer {
        let loc = Localizer()
        let config = LocalizationConfig(
            defaultLanguage: defaultLanguage,
            fallbackLanguage: fallbackLanguage,
            bundledResource: defaultLanguage,
            bundle: .module,
            cacheDirectory: TestSupport.makeTempDir(),
            parser: parser
        )
        loc.configure(config)
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

    // MARK: Applying consumer-fetched bundles

    func testApplyBundleSwapsActiveTableLive() throws {
        let loc = makeLocalizer(default: "en", fallback: "en")
        XCTAssertEqual(loc.t("auth.login"), "Log in")

        try loc.applyBundle(TestSupport.data(#"{"auth":{"login":"Signed in (applied)"}}"#), for: "en")
        XCTAssertEqual(loc.t("auth.login"), "Signed in (applied)")
    }

    func testApplyBundlePostsNotification() throws {
        let loc = makeLocalizer(default: "en", fallback: "en")
        let expectation = XCTNSNotificationExpectation(name: .aksaraDidChange, object: loc)
        try loc.applyBundle(TestSupport.data(#"{"auth":{"login":"X"}}"#), for: "en")
        wait(for: [expectation], timeout: 1.0)
    }

    func testApplyBundleParseFailureKeepsLastGood() {
        let loc = makeLocalizer(default: "en", fallback: "en")
        XCTAssertThrowsError(try loc.applyBundle(TestSupport.data("garbage {"), for: "en"))
        XCTAssertEqual(loc.t("auth.login"), "Log in") // unchanged
    }

    func testApplyBundleForInactiveLanguageIsCachedThenUsedOnSetLanguage() throws {
        let loc = makeLocalizer(default: "en", fallback: "en")
        // Applying "de" (not active, not fallback) shouldn't change the visible table…
        try loc.applyBundle(TestSupport.data(#"{"auth":{"login":"Anmelden"}}"#), for: "de")
        XCTAssertEqual(loc.currentLanguage, "en")
        XCTAssertEqual(loc.t("auth.login"), "Log in")
        // …but switching to it picks up the cached bundle.
        loc.setLanguage("de")
        XCTAssertEqual(loc.t("auth.login"), "Anmelden")
    }

    func testUpdateUsesConsumerSuppliedFetch() async throws {
        let loc = makeLocalizer(default: "en", fallback: "en")
        try await loc.update(for: "en") { _ in
            TestSupport.data(#"{"auth":{"login":"Fetched by consumer"}}"#)
        }
        XCTAssertEqual(loc.t("auth.login"), "Fetched by consumer")
    }

    func testApplyBundleBeforeConfigureThrows() {
        let loc = Localizer()
        XCTAssertThrowsError(try loc.applyBundle(TestSupport.data("{}"), for: "en")) { error in
            XCTAssertEqual(error as? AksaraError, .notConfigured)
        }
    }

    // MARK: Custom parser (consumer-defined JSON model)

    func testCustomParserFormat() throws {
        let loc = makeLocalizer(default: "en", fallback: "en", parser: ListParser())
        try loc.applyBundle(
            TestSupport.data(#"{"items":[{"id":"auth.login","text":"Signed in (custom)"}]}"#),
            for: "en"
        )
        XCTAssertEqual(loc.t("auth.login"), "Signed in (custom)")
    }

    // MARK: Warm-start cache

    func testCachedBundlePreferredOverBundledOnConfigure() {
        // Pre-seed the cache as if a bundle was applied previously, then configure fresh.
        let tempDir = TestSupport.makeTempDir()
        DiskCache(directory: tempDir).saveBundle(
            TestSupport.data(#"{"auth":{"login":"From cache"}}"#), language: "en"
        )

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
