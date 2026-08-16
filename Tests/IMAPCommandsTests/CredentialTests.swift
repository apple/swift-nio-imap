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
import Foundation
import NIOIMAP
import Testing

@Suite private enum CredentialTests {
    @Test static func parsingURL() throws {
        #expect(
            try IMAPCredential(url: "imap://foo:bar@mail.example.com", sasl: nil, username: nil)
                == IMAPCredential.username("foo", password: "bar")
        )
    }

    @Test static func parsingUsername() throws {
        #expect(
            try IMAPCredential(url: nil, sasl: nil, username: "foo:bar")
                == IMAPCredential.username("foo", password: "bar")
        )

        #expect(
            try IMAPCredential(url: "imap://mail.example.com", sasl: nil, username: "foo:bar")
                == IMAPCredential.username("foo", password: "bar")
        )
    }

    @Test static func parsingSASL_stringsSeparatedBySpace() throws {
        #expect(
            try IMAPCredential(url: nil, sasl: "EXTERNAL:11485857054 18570541485 asbbc/asdfa", username: nil)
                == IMAPCredential.sasl(
                    mechanism: AuthenticationMechanism("EXTERNAL")!,
                    response: Data(base64Encoded: "MTE0ODU4NTcwNTQAMTg1NzA1NDE0ODUAYXNiYmMvYXNkZmE=")!
                )
        )

        #expect(
            try IMAPCredential(url: nil, sasl: "external:11485857054 18570541485 asbbc/asdfa", username: nil)
                == IMAPCredential.sasl(
                    mechanism: AuthenticationMechanism("EXTERNAL")!,
                    response: Data(base64Encoded: "MTE0ODU4NTcwNTQAMTg1NzA1NDE0ODUAYXNiYmMvYXNkZmE=")!
                )
        )

        #expect(
            try IMAPCredential(url: nil, sasl: "plain:foo bar", username: nil)
                == IMAPCredential.sasl(mechanism: .plain, response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        )

        #expect(
            try IMAPCredential(url: "imap://mail.example.com", sasl: "plain:foo bar", username: nil)
                == IMAPCredential.sasl(mechanism: .plain, response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        )
    }

    @Test static func parsingSASL_singleBase64() throws {
        #expect(
            try IMAPCredential(url: nil, sasl: "PLAIN:dGVzdAB0ZXN0AHRlc3Q=", username: nil)
                == IMAPCredential.sasl(mechanism: .plain, response: Data(base64Encoded: "dGVzdAB0ZXN0AHRlc3Q=")!)
        )

        // Not valid base64 (the length is not a multiple of 4), and hence a single part:
        #expect(
            try IMAPCredential(url: nil, sasl: "PLAIN:foo", username: nil)
                == IMAPCredential.sasl(mechanism: .plain, response: Data("foo".utf8))
        )
    }

    /// An empty response is valid and results in a zero byte response.
    @Test static func parsingSASL_emptyResponse() throws {
        #expect(
            try IMAPCredential(url: nil, sasl: "PLAIN:", username: nil)
                == IMAPCredential.sasl(mechanism: .plain, response: Data())
        )
    }

    /// Mechanism names may contain digits, `-` and `_`, not just letters.
    ///
    /// See [RFC 4422 section 3.1](https://datatracker.ietf.org/doc/html/rfc4422#section-3.1).
    @Test(
        arguments: [
            "XOAUTH2",
            "SCRAM-SHA-256",
            "CRAM-MD5",
            "DIGEST-MD5",
            "X_SOMETHING",
        ]
    )
    static func parsingSASL_mechanismName(_ name: String) throws {
        #expect(
            try IMAPCredential(url: nil, sasl: "\(name):foo bar", username: nil)
                == IMAPCredential.sasl(
                    mechanism: AuthenticationMechanism(name)!,
                    response: Data(base64Encoded: "Zm9vAGJhcg==")!
                )
        )

        // The name is normalized to uppercase.
        #expect(
            try IMAPCredential(url: nil, sasl: "\(name.lowercased()):foo bar", username: nil)
                == IMAPCredential.sasl(
                    mechanism: AuthenticationMechanism(name)!,
                    response: Data(base64Encoded: "Zm9vAGJhcg==")!
                )
        )
    }

    @Test(
        arguments: [
            "",
            "PLAIN",
            ":foo bar",
            "PL.AIN:foo bar",
            "PLAIN: foo bar",
            "PLAIN:\tfoo bar",
        ]
    )
    static func parsingInvalidSASL(_ text: String) throws {
        #expect(throws: (any Error).self) {
            try IMAPCredential(url: nil, sasl: text, username: nil)
        }
    }

    @Test(
        arguments: [
            "",
            "foo",
            "foo:",
            ":bar",
            "foo:bar:baz",
        ]
    )
    static func parsingInvalidUsername(_ text: String) throws {
        #expect(throws: (any Error).self) {
            try IMAPCredential(url: nil, sasl: nil, username: text)
        }
    }

    @Test static func multipleUsername() throws {
        #expect(throws: (any Error).self) {
            try IMAPCredential(url: "imap://foo:bar@mail.example.com", sasl: nil, username: "foo:bar")
        }
    }

    @Test static func saslAndUsername() throws {
        #expect(throws: (any Error).self) {
            try IMAPCredential(url: "imap://foo:bar@mail.example.com", sasl: "plain:foo bar", username: nil)
        }
        #expect(throws: (any Error).self) {
            try IMAPCredential(url: nil, sasl: "plain:foo bar", username: "foo:bar")
        }
    }

    @Test static func descriptionRedactsSecret() throws {
        // The password must not appear in the description.
        let userCredential = IMAPCredential.username("foo", password: "s3cr3t")
        #expect(!userCredential.description.contains("s3cr3t"))
        #expect(userCredential.description == "foo:[6 bytes]")

        // The SASL response must not be leaked (not even base64-encoded).
        let sasl = IMAPCredential.sasl(mechanism: .plain, response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        #expect(!sasl.description.contains("Zm9vAGJhcg=="))
        #expect(sasl.description == "SASL PLAIN [7 bytes]")
    }
}
