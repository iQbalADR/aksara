import XCTest
@testable import Aksara

final class DiskCacheTests: XCTestCase {
    func testSaveAndLoadRoundTrip() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        let payload = TestSupport.data(#"{"a":"b"}"#)
        cache.saveBundle(payload, etag: "v1", language: "en")

        XCTAssertEqual(cache.loadBundle(language: "en"), payload)
        XCTAssertEqual(cache.loadETag(language: "en"), "v1")
    }

    func testMissingLanguageReturnsNil() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        XCTAssertNil(cache.loadBundle(language: "fr"))
        XCTAssertNil(cache.loadETag(language: "fr"))
    }

    func testClearRemovesEntry() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data("{}"), etag: "v1", language: "en")
        cache.clear(language: "en")
        XCTAssertNil(cache.loadBundle(language: "en"))
        XCTAssertNil(cache.loadETag(language: "en"))
    }

    func testLanguagesAreIsolated() {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data(#"{"x":"en"}"#), etag: "e", language: "en")
        cache.saveBundle(TestSupport.data(#"{"x":"id"}"#), etag: "i", language: "id")
        XCTAssertEqual(cache.loadETag(language: "en"), "e")
        XCTAssertEqual(cache.loadETag(language: "id"), "i")
    }
}
