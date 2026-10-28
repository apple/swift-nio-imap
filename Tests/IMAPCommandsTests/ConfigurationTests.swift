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
import Testing

private enum ConfigurationTests {
    @Test
    static func parseNameOnly() throws {
        #expect(
            try IMAPConnection.Configuration(serverText: "mail.example.com", logging: .noLogging)
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 993,
                    useTLS: true,
                    logging: .noLogging
                )
        )

        #expect(
            try IMAPConnection.Configuration(serverText: "mail.example.com:993", logging: .noLogging)
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 993,
                    useTLS: true,
                    logging: .noLogging
                )
        )

        #expect(
            try IMAPConnection.Configuration(serverText: "mail.example.com:143", logging: .noLogging)
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 143,
                    useTLS: false,
                    logging: .noLogging
                )
        )

        #expect(
            try IMAPConnection.Configuration(serverText: "mail.example.com:1000", logging: .noLogging)
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 1000,
                    useTLS: false,
                    logging: .noLogging
                )
        )
    }

    // https://tools.ietf.org/html/rfc5092
    @Test
    static func testParsingURL() throws {
        #expect(
            try IMAPConnection.Configuration(serverText: "imap://mail.example.com", logging: .noLogging)
                == IMAPConnection.Configuration(
                    hostname: "mail.example.com",
                    port: 993,
                    useTLS: true,
                    logging: .noLogging
                )
        )
    }

    /// Text that is neither a hostname (with optional port) nor an IMAP URL is rejected.
    ///
    /// Anything following the port is _not_ ignored: such text falls through to URL parsing,
    /// which then fails because the scheme is not `imap`.
    @Test(
        arguments: [
            "",
            "mail.example.com:143abc",
            "mail.example.com:143:144",
            "mail.example.com:65536",
            "mail.example.com:",
            "mail..example.com",
            ".mail.example.com",
            "mail.example.com.",
            "-mail.example.com",
            "mail.example.com-",
            "mail.example.com/inbox",
            "http://mail.example.com",
        ]
    )
    static func parsingInvalidServerText(_ text: String) throws {
        #expect(throws: (any Error).self) {
            try IMAPConnection.Configuration(serverText: text, logging: .noLogging)
        }
    }
}
