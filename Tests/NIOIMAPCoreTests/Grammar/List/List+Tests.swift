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
