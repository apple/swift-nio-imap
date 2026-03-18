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
        ParseFixture.messageIdentifierSet("0", "\r\n", expected: .failure),
        ParseFixture.messageIdentifierSet("1234", "", expected: .incompleteMessage),
        ParseFixture.messageIdentifierSet("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<MessageIdentifierSet<UID>>) {
        fixture.checkParsing()
    }

    @Test("convert to sequence number")
    func convertToSequenceNumber() {
        let input = MessageIdentifierSet<UnknownMessageIdentifier>([1...5, 10...15, 20...30])
        let output = MessageIdentifierSet<SequenceNumber>(input)
        #expect(output == [1...5, 10...15, 20...30])
    }

    @Test("convert to UID")
    func convertToUID() {
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

    @Test("RangeView array literal initializer")
    func rangeViewArrayLiteral() {
        let rv: MessageIdentifierSet<UID>.RangeView = [MessageIdentifierRange<UID>(1...5)]
        let set = UIDSet([1...5])
        #expect(rv == set.ranges)
    }

    @Test("RangeView equality")
    func rangeViewEquality() {
        let set1 = UIDSet([1...5, 10...15])
        let set2 = UIDSet([1...5, 10...15])
        let set3 = UIDSet([1...5])
        #expect(set1.ranges == set2.ranges)
        #expect(set1.ranges != set3.ranges)
    }

    @Test("init from ClosedRange")
    func initFromClosedRange() {
        let set = MessageIdentifierSet<UID>(1...10 as ClosedRange<UID>)
        #expect(set == UIDSet([1...10]))
    }

    @Test("init from PartialRangeThrough")
    func initFromPartialRangeThrough() {
        let set = MessageIdentifierSet<UID>(...10 as PartialRangeThrough<UID>)
        #expect(set == UIDSet([1...10]))
    }

    @Test("init from PartialRangeFrom")
    func initFromPartialRangeFrom() {
        let set = MessageIdentifierSet<UID>(1... as PartialRangeFrom<UID>)
        #expect(set.contains(1))
        #expect(set.contains(UID(rawValue: 4_294_967_295)))
    }

    @Test(
        "init from Range",
        arguments: [
            (1..<1 as Range<UID>, UIDSet()),
            (1..<5 as Range<UID>, UIDSet([1...4])),
        ] as [(Range<UID>, UIDSet)]
    )
    func initFromRange(_ fixture: (Range<UID>, UIDSet)) {
        #expect(MessageIdentifierSet<UID>(fixture.0) == fixture.1)
    }

    @Test("Index comparison operators")
    func indexComparison() {
        let set = UIDSet([1...3, 10...12])
        let indices = Array(set.indices)
        // indices[0] < indices[1] < indices[2] < indices[3] etc.
        #expect(indices[0] < indices[1])
        #expect(indices[1] > indices[0])
        #expect(!(indices[0] > indices[1]))
        // Compare across range boundaries
        #expect(indices[2] < indices[3])
        #expect(indices[3] > indices[2])
    }

    @Test("convert UnknownMessageIdentifier from UID set")
    func convertUnknownFromUID() {
        let uidSet: MessageIdentifierSet<UID> = [1...5, 10...15]
        let unknown = MessageIdentifierSet<UnknownMessageIdentifier>(uidSet)
        #expect(unknown == [1...5, 10...15])
    }

    @Test("convert UnknownMessageIdentifier from SequenceNumber set")
    func convertUnknownFromSequenceNumber() {
        let seqSet: MessageIdentifierSet<SequenceNumber> = [1...5, 10...15]
        let unknown = MessageIdentifierSet<UnknownMessageIdentifier>(seqSet)
        #expect(unknown == [1...5, 10...15])
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
