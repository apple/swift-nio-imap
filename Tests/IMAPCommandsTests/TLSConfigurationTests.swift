//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@testable import IMAPCommands
import NIOSSL
import Testing

/// `IMAPConnection.Configuration.tlsConfiguration`, against a loopback server speaking TLS
/// with a self-signed certificate for `localhost`.
private enum TLSConfigurationTests {
    @Test(.timeLimit(.minutes(1)))
    static func trustsACustomRoot() async throws {
        let server = try await LoopbackServer.greetThenStayOpen(tls: try serverTLS())
        defer { server.shutdown() }

        let greeting = try await IMAPConnection.withConnection(
            configuration: clientConfiguration(port: server.port, tls: try clientTLS())
        ) { greeting, _ in greeting }
        #expect("\(greeting)".contains("Loopback test server ready"))
    }

    @Test(.timeLimit(.minutes(1)))
    static func verifiesCertificatesByDefault() async throws {
        let server = try await LoopbackServer.greetThenStayOpen(tls: try serverTLS())
        defer { server.shutdown() }

        await #expect(throws: (any Error).self) {
            try await IMAPConnection.withConnection(
                configuration: clientConfiguration(port: server.port, tls: .makeClientConfiguration())
            ) { _, _ in }
        }
    }

    /// A server that offers nothing newer than TLS 1.1 is accepted by default, and refused once
    /// the minimum is TLS 1.2.
    @Test(.timeLimit(.minutes(1)))
    static func minimumTLSVersionRefusesAnOlderServer() async throws {
        var old = try serverTLS()
        old.minimumTLSVersion = .tlsv1
        old.maximumTLSVersion = .tlsv11
        let server = try await LoopbackServer.greetThenStayOpen(tls: old)
        defer { server.shutdown() }

        _ = try await IMAPConnection.withConnection(
            configuration: clientConfiguration(port: server.port, tls: try clientTLS())
        ) { greeting, _ in greeting }

        var modern = try clientTLS()
        modern.minimumTLSVersion = .tlsv12
        await #expect(throws: (any Error).self) {
            try await IMAPConnection.withConnection(
                configuration: clientConfiguration(port: server.port, tls: modern)
            ) { _, _ in }
        }
    }

    @Test
    static func equality() throws {
        let plain = IMAPConnection.Configuration(
            hostname: "mail.example.com",
            port: 993,
            useTLS: true,
            logging: .noLogging
        )
        #expect(
            plain
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 993,
                    useTLS: true,
                    tlsConfiguration: .makeClientConfiguration(),
                    logging: .noLogging
                )
        )

        var stricter = plain
        stricter.tlsConfiguration.minimumTLSVersion = .tlsv12
        #expect(plain != stricter)
    }

    // MARK: -

    private static func clientConfiguration(port: UInt16, tls: TLSConfiguration) -> IMAPConnection.Configuration {
        IMAPConnection.Configuration(
            hostname: "localhost",
            port: port,
            useTLS: true,
            tlsConfiguration: tls,
            logging: .noLogging
        )
    }

    private static func serverTLS() throws -> TLSConfiguration {
        TLSConfiguration.makeServerConfiguration(
            certificateChain: [.certificate(try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem))],
            privateKey: .privateKey(try NIOSSLPrivateKey(bytes: Array(privateKeyPEM.utf8), format: .pem))
        )
    }

    /// Trusts the test certificate, and nothing else.
    private static func clientTLS() throws -> TLSConfiguration {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.trustRoots = .certificates([try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)])
        return tls
    }

    /// Self-signed, P-256, for `localhost`, valid until 2126. Test use only.
    private static let certificatePEM = """
        -----BEGIN CERTIFICATE-----
        MIIBdTCCARqgAwIBAgIUcIA5dmLbYJWmZbmzh4u1h4hnY98wCgYIKoZIzj0EAwIw
        FDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MTEwNjE5MjMzOVoYDzIxMjYxMDEz
        MTkyMzM5WjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwWTATBgcqhkjOPQIBBggqhkjO
        PQMBBwNCAARPzJH9mgvX9z9f0S6ubxP6J6bfQDbuRXbLyuGthmbbcqtQsMoCq8VQ
        mZBPsDQFGU3csAeg7VJkcVoSsfqjRDBCo0gwRjAdBgNVHQ4EFgQUS4AOxTfSw6sr
        BmUTRKpqyCWPtTEwFAYDVR0RBA0wC4IJbG9jYWxob3N0MA8GA1UdEwEB/wQFMAMB
        Af8wCgYIKoZIzj0EAwIDSQAwRgIhAJ9wBi6GOFU1Strn8ZJtlBi4Pyw7D5fEa+Se
        y3JP3pIZAiEAx5d5RHxMPvud1hcvxxsXobFAsUqsjc8PbBdXp78ueFo=
        -----END CERTIFICATE-----
        """

    private static let privateKeyPEM = """
        -----BEGIN PRIVATE KEY-----
        MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQg6GFO3Nt9UFm1j9gY
        T1bj1g0aNayonI7r65SjwUfDtxOhRANCAARPzJH9mgvX9z9f0S6ubxP6J6bfQDbu
        RXbLyuGthmbbcqtQsMoCq8VQmZBPsDQFGU3csAeg7VJkcVoSsfqjRDBC
        -----END PRIVATE KEY-----
        """
}
