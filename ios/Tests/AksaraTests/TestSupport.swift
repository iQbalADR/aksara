import Foundation
import XCTest
@testable import Aksara

/// A scripted `RemoteBundleFetcher` for OTA tests. Records what was requested and
/// returns queued outcomes in order.
final class MockFetcher: RemoteBundleFetcher, @unchecked Sendable {
    private var outcomes: [Result<FetchOutcome, Error>]
    private(set) var requestedURLs: [URL] = []
    private(set) var sentETags: [String?] = []

    init(_ outcomes: [Result<FetchOutcome, Error>]) {
        self.outcomes = outcomes
    }

    func fetch(url: URL, etag: String?) async throws -> FetchOutcome {
        requestedURLs.append(url)
        sentETags.append(etag)
        guard !outcomes.isEmpty else { throw OTAError.invalidResponse }
        return try outcomes.removeFirst().get()
    }
}

enum TestSupport {
    /// A throwaway directory unique per call — keeps each test's disk cache isolated.
    static func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("AksaraTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func data(_ json: String) -> Data { Data(json.utf8) }
}
