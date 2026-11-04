//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("EncodedAuthenticatedURL")
struct EncodedAuthenticatedURLTests {
    /// A token is written to the wire verbatim, inside a URL that is itself written bare.
    @Test(
        "invalid tokens are rejected",
        arguments: [
            "",
            "0123456789abcdef0123456789abcde",  // `32*HEXDIG`: 31 digits.
            "0123456789abcdef0123456789abcdeg",
            "0123456789abcdef0123456789abcdef ",
            "0123456789abcdef0123456789abcdef\r\n* BYE",  // Would inject a whole response.
        ]
    )
    func invalidTokens(_ string: String) {
        #expect(EncodedAuthenticatedURL(string) == nil)
    }

    @Test("valid tokens", arguments: validTokenStrings)
    func validTokens(_ string: String) {
        #expect(EncodedAuthenticatedURL(string).map { String($0) } == string)
    }

    @Test("valid tokens round-trip", arguments: validTokenStrings)
    func validTokensRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            try #require(EncodedAuthenticatedURL(string)),
            encoder: { $0.writeEncodedAuthenticationURL($1) },
            parser: GrammarParser().parseEncodedURLAuth
        )
    }

    @Test(arguments: [
        EncodeFixture.encodedAuthenticationURL(
            "0123456789ABCDEF0123456789ABCDEF",
            "0123456789ABCDEF0123456789ABCDEF"
        )
    ])
    func encode(_ fixture: EncodeFixture<EncodedAuthenticatedURL>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedAuthenticationURL(
            "0123456789abcdef01234567890abcde",
            " ",
            expected: .success("0123456789abcdef01234567890abcde")
        ),
        // `32*HEXDIG`: reads past 32.
        ParseFixture.encodedAuthenticationURL(
            "0123456789abcdef01234567890abcdef0",
            " ",
            expected: .success("0123456789abcdef01234567890abcdef0")
        ),
        ParseFixture.encodedAuthenticationURL(
            "0123456789abcdef01234567890abcd",
            " ",
            expected: .failure
        ),
        ParseFixture.encodedAuthenticationURL(
            "0123456789zbcdef01234567890abcde",
            "",
            expected: .failure
        ),
        ParseFixture.encodedAuthenticationURL(
            "0123456789",
            "",
            expected: .incompleteMessage
        ),
    ])
    func parse(_ fixture: ParseFixture<EncodedAuthenticatedURL>) {
        fixture.checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let token: EncodedAuthenticatedURL = "1F"
                _ = token
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid URLAUTH token")
    }
    #endif
}

// MARK: -

private let validTokenStrings = [
    "0123456789abcdef0123456789abcdef",
    "0123456789ABCDEF0123456789ABCDEF0123",
]

extension EncodeFixture<EncodedAuthenticatedURL> {
    fileprivate static func encodedAuthenticationURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeEncodedAuthenticationURL($1) }
        )
    }
}

extension ParseFixture<EncodedAuthenticatedURL> {
    fileprivate static func encodedAuthenticationURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedURLAuth
        )
    }
}
