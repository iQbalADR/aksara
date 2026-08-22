import Foundation

/// Errors surfaced by the OTA path. Any of these means "keep last-good".
public enum OTAError: Error, Equatable, Sendable {
    case httpStatus(Int)
    case invalidResponse
}

/// The result of a single conditional fetch.
public enum FetchOutcome: Sendable {
    /// Server replied `304 Not Modified` — the cached ETag is still current.
    case notModified
    /// A fresh payload, plus its new ETag (if the server sent one).
    case updated(data: Data, etag: String?)
}

/// Abstraction over "GET the bundle for a language, conditionally". The default
/// implementation uses `URLSession` with certificate pinning; tests inject a mock.
public protocol RemoteBundleFetcher: Sendable {
    func fetch(url: URL, etag: String?) async throws -> FetchOutcome
}

/// Production fetcher: conditional GET (`If-None-Match`) over a pinned TLS session.
public final class URLSessionBundleFetcher: RemoteBundleFetcher, @unchecked Sendable {
    private let session: URLSession

    /// - Parameter pinnedCertificateHashes: `base64(SHA-256(DER cert))` values.
    ///   Empty set disables pinning (default system trust only).
    public init(pinnedCertificateHashes: Set<String> = []) {
        // The session strongly retains the delegate until it is invalidated, so a
        // separate delegate object keeps `session` an immutable `let`.
        let delegate = PinningDelegate(pins: pinnedCertificateHashes)
        self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }

    public func fetch(url: URL, etag: String?) async throws -> FetchOutcome {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OTAError.invalidResponse
        }
        if http.statusCode == 304 {
            return .notModified
        }
        guard (200...299).contains(http.statusCode) else {
            throw OTAError.httpStatus(http.statusCode)
        }
        let newETag = http.value(forHTTPHeaderField: "ETag")
        return .updated(data: data, etag: newETag)
    }
}

/// Session delegate that enforces certificate pinning on the server-trust challenge.
private final class PinningDelegate: NSObject, URLSessionDelegate {
    private let pins: Set<String>

    init(pins: Set<String>) {
        self.pins = pins
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        if CertificatePinner.validate(trust: trust, against: pins) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
