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

@Suite("MessageIdentifierSet")
struct MessageIdentifierSetTests {
    @Test(arguments: [
        ParseFixture.messageIdentifierSet("1234", "\r\n", expected: .success(MessageIdentifierSet(1234 as UID))),
        ParseFixture.messageIdentifierSet(
            "12:34",
            "\r\n",
            expected: .success(MessageIdentifierSet(MessageIdentifierRange<UID>(12...34)))
        ),
        ParseFixture.messageIdentifierSet(
            "1,2,34:56,78:910,11",
            "\r\n",
            expected: .success(
                MessageIdentifierSet([
                    MessageIdentifierRange<UID>(1),
                    MessageIdentifierRange<UID>(2),
                    MessageIdentifierRange<UID>(34...56),
                    MessageIdentifierRange<UID>(78...910),
                    MessageIdentifierRange<UID>(11),
                ])
            )
        ),
        ParseFixture.messageIdentifierSet(
            "*",
            "\r\n",
            expected: .success(MessageIdentifierSet(MessageIdentifierRange<UID>(.max)))
        ),
        ParseFixture.messageIdentifierSet("1:*", "\r\n", expected: .success(.all)),
        ParseFixture.messageIdentifierSet("a", " ", expected: .failure),
        ParseFixture.messageIdentifierSet("1234", "", expected: .incompleteMessage),
        ParseFixture.messageIdentifierSet("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<MessageIdentifierSet<UID>>) {
        fixture.checkParsing()
    }

    @Test func `convert to sequence number`() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<SequenceNumber>(input)
        #expect(output == [1...5, 10...15, 20...30])
    }

    @Test func `convert to UID`() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<UID>(input)
        #expect(output == [1...5, 10...15, 20...30])
    }

    @Test func suffix() {
        #expect(UIDSet().suffix(0) == UIDSet())
        #expect(UIDSet([1]).suffix(0) == UIDSet())
        #expect(UIDSet([100, 200]).suffix(0) == UIDSet())

        #expect(UIDSet([100, 200]).suffix(1) == UIDSet([200]))
        #expect(UIDSet([100, 200]).suffix(2) == UIDSet([100, 200]))
        #expect(UIDSet([100, 200]).suffix(3) == UIDSet([100, 200]))

        #expect(UIDSet([200...299]).suffix(0) == UIDSet())
        #expect(UIDSet([200...299]).suffix(1) == UIDSet([299]))
        #expect(UIDSet([200...299]).suffix(2) == UIDSet([298...299]))
        #expect(UIDSet([200...299]).suffix(3) == UIDSet([297...299]))

        #expect(UIDSet([100, 200...299]).suffix(0) == UIDSet())
        #expect(UIDSet([100, 200...299]).suffix(1) == UIDSet([299]))
        #expect(UIDSet([100, 200...299]).suffix(2) == UIDSet([298...299]))
        #expect(UIDSet([100, 200...299]).suffix(3) == UIDSet([297...299]))

        #expect(UIDSet([100...102, 200...202]).suffix(0) == UIDSet())
        #expect(UIDSet([100...102, 200...202]).suffix(1) == UIDSet([202]))
        #expect(UIDSet([100...102, 200...202]).suffix(2) == UIDSet([201...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(3) == UIDSet([200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(4) == UIDSet([102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(5) == UIDSet([101...102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(6) == UIDSet([100...102, 200...202]))
        #expect(UIDSet([100...102, 200...202]).suffix(7) == UIDSet([100...102, 200...202]))

        #expect(UIDSet.all.suffix(0) == UIDSet())
        #expect(UIDSet.all.suffix(1) == UIDSet([4_294_967_295]))
        #expect(UIDSet.all.suffix(2) == UIDSet([4_294_967_294...4_294_967_295]))
    }
}

// MARK: -

extension ParseFixture<MessageIdentifierSet<UID>> {
    fileprivate static func messageIdentifierSet(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUIDSet
        )
    }
}
