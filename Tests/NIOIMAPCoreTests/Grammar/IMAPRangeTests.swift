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

@Suite("IMAP Range")
struct IMAPRangeTests {
    @Test(arguments: [
        EncodeFixture.sequenceRange(MessageIdentifierRange<SequenceNumber>(5...), "5:*"),
        EncodeFixture.sequenceRange(MessageIdentifierRange<SequenceNumber>(2...4), "2:4"),
    ])
    func encode(_ fixture: EncodeFixture<MessageIdentifierRange<SequenceNumber>>) {
        fixture.checkEncoding()
    }

    @Test func `range from`() {
        let sut = MessageIdentifierRange<SequenceNumber>(7...)
        #expect(sut.range.lowerBound == 7)
        #expect(sut.range.upperBound == .max)
    }

    @Test func `range to`() {
        let sut = MessageIdentifierRange<SequenceNumber>(...7)
        #expect(sut.range.lowerBound == 1)
        #expect(sut.range.upperBound == 7)
    }

    @Test func `range closed`() {
        let sut = MessageIdentifierRange<SequenceNumber>(3...4)
        #expect(sut.range.lowerBound == 3)
        #expect(sut.range.upperBound == 4)
    }
}

// MARK: -

extension EncodeFixture<MessageIdentifierRange<SequenceNumber>> {
    fileprivate static func sequenceRange(
        _ input: MessageIdentifierRange<SequenceNumber>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSequenceRange($1) }
        )
    }
}
