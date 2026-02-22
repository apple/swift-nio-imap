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

@Suite("MessageIdentifierRange")
struct MessageIdentifierRangeTests {
    @Test(arguments: [
        ParseFixture.messageIdentifierRange("*", "\r\n", expected: .success(MessageIdentifierRange<UID>(.max))),
        ParseFixture.messageIdentifierRange("1:*", "\r\n", expected: .success(MessageIdentifierRange<UID>.all)),
        ParseFixture.messageIdentifierRange("12:34", "\r\n", expected: .success(MessageIdentifierRange<UID>(12...34))),
        ParseFixture.messageIdentifierRange(
            "12:*",
            "\r\n",
            expected: .success(MessageIdentifierRange<UID>(12 ... .max))
        ),
        ParseFixture.messageIdentifierRange(
            "1:34",
            "\r\n",
            expected: .success(MessageIdentifierRange<UID>((.min)...34))
        ),
        ParseFixture.messageIdentifierRange("!", " ", expected: .failure),
        ParseFixture.messageIdentifierRange("a", " ", expected: .failure),
        ParseFixture.messageIdentifierRange("1", "", expected: .incompleteMessage)
    ])
    func parse(_ fixture: ParseFixture<MessageIdentifierRange<UID>>) {
        fixture.checkParsing()
    }

    @Test("convert to sequence number")
    func convertToSequenceNumber() {
        let input = MessageIdentifierRange<UnknownMessageIdentifier>(UnknownMessageIdentifier(1)...2)
        let output = MessageIdentifierRange<SequenceNumber>(input)
        #expect(output == 1...2)
    }

    @Test("convert to UID")
    func convertToUID() {
        let input = MessageIdentifierRange<UnknownMessageIdentifier>(UnknownMessageIdentifier(5)...6)
        let output = MessageIdentifierRange<UID>(input)
        #expect(output == 5...6)
    }
}

// MARK: -

extension ParseFixture<MessageIdentifierRange<UID>> {
    fileprivate static func messageIdentifierRange(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessageIdentifierRange
        )
    }
}
