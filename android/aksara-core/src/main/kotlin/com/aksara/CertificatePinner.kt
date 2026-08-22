package com.aksara

import java.security.KeyStore
import java.security.MessageDigest
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.util.Base64
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

/**
 * Certificate pinning for the OTA endpoint.
 *
 * A pin is `base64( SHA-256( DER-encoded certificate ) )` — the **same format as the
 * Swift `CertificatePinner`**. The handshake is rejected unless one of the presented
 * chain certificates matches a configured pin, so a MITM with a valid-but-different
 * cert can't serve a poisoned bundle.
 *
 * Extract a pin for your endpoint with:
 * ```
 * openssl s_client -connect cdn.example.com:443 </dev/null 2>/dev/null \
 *   | openssl x509 -outform der | openssl dgst -sha256 -binary | openssl base64
 * ```
 *
 * Standard chain validation runs first (via the platform default trust manager); pins
 * are an additional constraint on top.
 */
internal object CertificatePinner {

    fun socketFactory(pins: Set<String>): SSLSocketFactory {
        val context = SSLContext.getInstance("TLS")
        context.init(null, arrayOf(PinningTrustManager(pins, defaultTrustManager())), null)
        return context.socketFactory
    }

    fun sha256Base64(der: ByteArray): String =
        Base64.getEncoder().encodeToString(MessageDigest.getInstance("SHA-256").digest(der))

    private fun defaultTrustManager(): X509TrustManager {
        val factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        factory.init(null as KeyStore?)
        return factory.trustManagers.filterIsInstance<X509TrustManager>().first()
    }

    private class PinningTrustManager(
        private val pins: Set<String>,
        private val delegate: X509TrustManager,
    ) : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>, authType: String) =
            delegate.checkClientTrusted(chain, authType)

        override fun checkServerTrusted(chain: Array<out X509Certificate>, authType: String) {
            delegate.checkServerTrusted(chain, authType) // normal chain validation first
            val matched = chain.any { pins.contains(sha256Base64(it.encoded)) }
            if (!matched) throw CertificateException("no pinned certificate matched")
        }

        override fun getAcceptedIssuers(): Array<X509Certificate> = delegate.acceptedIssuers
    }
}
