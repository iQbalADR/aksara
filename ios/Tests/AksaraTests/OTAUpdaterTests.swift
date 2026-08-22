import XCTest
@testable import Aksara

final class OTAUpdaterTests: XCTestCase {
    private let base = URL(string: "https://cdn.example.com/i18n/")!

    func testUpdatedPayloadBuildsTableAndPersistsLastGood() async {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        let payload = TestSupport.data(#"{"common":{"welcome":"OTA {{name}}"}}"#)
        let fetcher = MockFetcher([.success(.updated(data: payload, etag: "v2"))])
        let updater = OTAUpdater(remoteBaseURL: base, fetcher: fetcher, cache: cache)

        let (result, table) = await updater.checkForUpdates(language: "en")

        XCTAssertEqual(result, .updated(language: "en"))
        XCTAssertEqual(table?.value(for: "common.welcome"), "OTA {{name}}")
        XCTAssertEqual(fetcher.requestedURLs.first?.absoluteString, "https://cdn.example.com/i18n/en.json")
        // Last-good persisted with its ETag.
        XCTAssertEqual(cache.loadBundle(language: "en"), payload)
        XCTAssertEqual(cache.loadETag(language: "en"), "v2")
    }

    func testStoredETagIsSentOnNextRequest() async {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data("{}"), etag: "existing-etag", language: "en")
        let fetcher = MockFetcher([.success(.notModified)])
        let updater = OTAUpdater(remoteBaseURL: base, fetcher: fetcher, cache: cache)

        let (result, table) = await updater.checkForUpdates(language: "en")

        XCTAssertEqual(result, .notModified)
        XCTAssertNil(table)
        XCTAssertEqual(fetcher.sentETags.first, "existing-etag")
    }

    func testMalformedPayloadFailsAndKeepsLastGood() async {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        cache.saveBundle(TestSupport.data(#"{"good":"data"}"#), etag: "v1", language: "en")
        let fetcher = MockFetcher([.success(.updated(data: TestSupport.data("garbage {"), etag: "v2"))])
        let updater = OTAUpdater(remoteBaseURL: base, fetcher: fetcher, cache: cache)

        let (result, table) = await updater.checkForUpdates(language: "en")

        XCTAssertEqual(result, .failed)
        XCTAssertNil(table)
        // Last-good untouched — the poisoned payload never overwrote it.
        XCTAssertEqual(cache.loadBundle(language: "en"), TestSupport.data(#"{"good":"data"}"#))
        XCTAssertEqual(cache.loadETag(language: "en"), "v1")
    }

    func testNetworkErrorFails() async {
        let cache = DiskCache(directory: TestSupport.makeTempDir())
        let fetcher = MockFetcher([.failure(OTAError.httpStatus(500))])
        let updater = OTAUpdater(remoteBaseURL: base, fetcher: fetcher, cache: cache)

        let (result, table) = await updater.checkForUpdates(language: "en")

        XCTAssertEqual(result, .failed)
        XCTAssertNil(table)
        XCTAssertNil(cache.loadBundle(language: "en"))
    }
}
