import Foundation
import CryptoKit

/// Certificate pinning for the OTA endpoint.
///
/// A pin is `base64( SHA-256( DER-encoded certificate ) )`. The fetcher rejects the
/// TLS handshake unless one of the presented chain certificates matches a configured
/// pin — so a MITM with a valid-but-different cert can't serve a poisoned bundle.
///
/// Extract a pin for your endpoint with:
/// ```
/// openssl s_client -connect cdn.example.com:443 </dev/null 2>/dev/null \
///   | openssl x509 -outform der | openssl dgst -sha256 -binary | openssl base64
/// ```
///
/// > This pins the whole DER certificate, so a pin must be updated whenever the
/// > endpoint's certificate is renewed.
enum CertificatePinner {
    static func validate(trust: SecTrust, against pins: Set<String>) -> Bool {
        guard !pins.isEmpty else { return true } // pinning disabled

        // The chain must first be valid per the system trust store.
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else { return false }

        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else {
            return false
        }
        for certificate in chain {
            let der = SecCertificateCopyData(certificate) as Data
            if pins.contains(sha256Base64(der)) {
                return true
            }
        }
        return false
    }

    private static func sha256Base64(_ data: Data) -> String {
        Data(SHA256.hash(data: data)).base64EncodedString()
    }
}
