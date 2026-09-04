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

@Suite("List")
struct ListTests {
    @Test("parse list wildcard", arguments: wildcardFixtures())
    func parseListWildcard(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse list mailbox",
        arguments: [
            // RFC 3501: list-mailbox = 1*list-char / string; list-char inherits
            // the CTL exclusion via ATOM-CHAR, and RFC 5234 has
            // CTL = %x00-1F / %x7F, so a bare list-mailbox stops at DEL and
            // cannot start with it.
            ParseFixture.listMailbox("ab", "\u{7F}c\r", expected: .success("ab")),
            ParseFixture.listMailbox("\u{7F}", "", expected: .failure),
        ]
    )
    func parseListMailbox(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }
}

// MARK: -

/// Generates ParseFixture instances for all 256 possible byte values.
/// Only '%' (0x25) and '*' (0x2A) are valid list wildcards.
private func wildcardFixtures() -> [ParseFixture<String>] {
    let validWildcards: Set<UInt8> = [UInt8(ascii: "%"), UInt8(ascii: "*")]

    return (UInt8.min...UInt8.max).map { byte in
        let input = String(decoding: [byte], as: UTF8.self)

        guard validWildcards.contains(byte) else {
            return ParseFixture.listWildcard(input, expected: .failureIgnoringBufferModifications)
        }
        let expected = String(Character(Unicode.Scalar(byte)))
        return ParseFixture.listWildcard(input, expected: .success(expected))
    }
}

extension ParseFixture<String> {
    fileprivate static func listMailbox(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                let buffer = try GrammarParser().parseListMailbox(buffer: &$0, tracker: $1)
                return String(buffer: buffer)
            }
        )
    }

    fileprivate static func listWildcard(
        _ input: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: "",
            expected: expected,
            parser: GrammarParser().parseListWildcards
        )
    }
}
