import XCTest
@testable import Aksara

final class DiskCacheTests: XCTestCase {
    func testSaveAndLoadRoundTrip() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        let payload = TestSupport.data(#"{"a":"b"}"#)
        cache.saveBundle(payload, language: "en")

        XCTAssertEqual(cache.loadBundle(language: "en"), payload)
    }

    func testMissingLanguageReturnsNil() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        XCTAssertNil(cache.loadBundle(language: "fr"))
    }

    func testClearRemovesEntry() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data("{}"), language: "en")
        cache.clear(language: "en")
        XCTAssertNil(cache.loadBundle(language: "en"))
    }

    func testLanguagesAreIsolated() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data(#"{"x":"en"}"#), language: "en")
        cache.saveBundle(TestSupport.data(#"{"x":"id"}"#), language: "id")
        XCTAssertEqual(cache.loadBundle(language: "en"), TestSupport.data(#"{"x":"en"}"#))
        XCTAssertEqual(cache.loadBundle(language: "id"), TestSupport.data(#"{"x":"id"}"#))
    }
}
