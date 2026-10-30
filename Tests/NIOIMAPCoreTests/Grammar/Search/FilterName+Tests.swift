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

@Suite("FilterName")
struct FilterNameTests {
    /// A name is written to the wire verbatim, so ``SearchKey/FilterName/init(_:)`` is the only thing
    /// between a caller that builds names from untrusted input and an injected command.
    @Test(
        "invalid names are rejected",
        arguments: [
            "",  // `1*<any ATOM-CHAR except "/">`.
            "a/b",
            "a b",
            "a(b",
            "a]b",
            #"a"b"#,
            #"a\b"#,
            "GRÜEZI",
            "a\u{7F}b",
            "x\r\nA2 DELETE INBOX",  // Would inject a whole command.
        ]
    )
    func invalidNames(_ string: String) {
        #expect(SearchKey.FilterName(string) == nil)
    }

    @Test("valid names", arguments: validNameStrings)
    func validNames(_ string: String) {
        #expect(SearchKey.FilterName(string).map { String($0) } == string)
    }

    /// Written verbatim, so every name we accept has to parse back unchanged.
    @Test("valid names round-trip", arguments: validNameStrings)
    func validNamesRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            SearchKey.filter(try #require(SearchKey.FilterName(string))),
            terminator: "\r",
            encoder: { $0.writeSearchKey($1) },
            parser: GrammarParser().parseSearchKey
        )
    }

    @Test(arguments: [
        ParseFixture.filterName("a", " ", expected: .success("a")),
        ParseFixture.filterName("abcdefg", " ", expected: .success("abcdefg")),
        // Stops at `/`: parsed names go through `init(unchecked:)`.
        ParseFixture.filterName("a", "/b", expected: .success("a")),
    ])
    func parse(_ fixture: ParseFixture<SearchKey.FilterName>) {
        fixture.checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let name: SearchKey.FilterName = "a/b"
                _ = name
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid filter name")
    }
    #endif
}

// MARK: -

private let validNameStrings = [
    "a",
    "on-the-road",
    "X.1+$",
]

extension ParseFixture<SearchKey.FilterName> {
    fileprivate static func filterName(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFilterName
        )
    }
}
