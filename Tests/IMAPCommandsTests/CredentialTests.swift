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
                    mechanism: "EXTERNAL",
                    response: Data(base64Encoded: "MTE0ODU4NTcwNTQAMTg1NzA1NDE0ODUAYXNiYmMvYXNkZmE=")!
                )
        )

        #expect(
            try IMAPCredential(url: nil, sasl: "external:11485857054 18570541485 asbbc/asdfa", username: nil)
                == IMAPCredential.sasl(
                    mechanism: "EXTERNAL",
                    response: Data(base64Encoded: "MTE0ODU4NTcwNTQAMTg1NzA1NDE0ODUAYXNiYmMvYXNkZmE=")!
                )
        )

        #expect(
            try IMAPCredential(url: nil, sasl: "plain:foo bar", username: nil)
                == IMAPCredential.sasl(mechanism: "PLAIN", response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        )

        #expect(
            try IMAPCredential(url: "imap://mail.example.com", sasl: "plain:foo bar", username: nil)
                == IMAPCredential.sasl(mechanism: "PLAIN", response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        )
    }

    @Test static func parsingSASL_singleBase64() throws {
        #expect(
            try IMAPCredential(url: nil, sasl: "PLAIN:dGVzdAB0ZXN0AHRlc3Q=", username: nil)
                == IMAPCredential.sasl(mechanism: "PLAIN", response: Data(base64Encoded: "dGVzdAB0ZXN0AHRlc3Q=")!)
        )
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
        let sasl = IMAPCredential.sasl(mechanism: "PLAIN", response: Data(base64Encoded: "Zm9vAGJhcg==")!)
        #expect(!sasl.description.contains("Zm9vAGJhcg=="))
        #expect(sasl.description == "SASL PLAIN [7 bytes]")
    }
}
