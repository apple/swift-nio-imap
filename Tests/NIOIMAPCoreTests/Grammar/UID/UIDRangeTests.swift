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

@Suite("UIDRange")
struct UIDRangeTests {
    @Test func wildcard() {
        let range = MessageIdentifierRange<UID>.all.range
        #expect(range.lowerBound == UID.min)
        #expect(range.upperBound == UID.max)
    }

    @Test func single() {
        let range = MessageIdentifierRange<UID>(999).range
        #expect(range.lowerBound == 999)
        #expect(range.upperBound == 999)
    }

    @Test func `init range`() {
        let range = MessageIdentifierRange<UID>(1...999).range
        #expect(range.lowerBound == 1)
        #expect(range.upperBound == 999)
    }

    @Test func `init integer`() {
        let range: MessageIdentifierRange<UID> = 654
        #expect(range.range.lowerBound == 654)
        #expect(range.range.upperBound == 654)
    }

    @Test func count() {
        #expect(MessageIdentifierRange<UID>(654...654).count == 1)
        #expect(MessageIdentifierRange<UID>(654).count == 1)
        #expect(MessageIdentifierRange<UID>(654...655).count == 2)
        #expect(MessageIdentifierRange<UID>(UID.min...UID.max).count == 4_294_967_295)
        #expect(MessageIdentifierRange<UID>(777...999).count == 223)
    }

    @Test func bounds() {
        #expect(MessageIdentifierRange<UID>(654).lowerBound == 654)
        #expect(MessageIdentifierRange<UID>(654).upperBound == 654)

        #expect(MessageIdentifierRange<UID>(777...999).lowerBound == 777)
        #expect(MessageIdentifierRange<UID>(777...999).upperBound == 999)
    }

    @Test func isEmpty() {
        #expect(!MessageIdentifierRange<UID>(654...654).isEmpty)
        #expect(!MessageIdentifierRange<UID>(654).isEmpty)
        #expect(!MessageIdentifierRange<UID>(654...655).isEmpty)
        #expect(!MessageIdentifierRange<UID>(UID.min...UID.max).isEmpty)
    }

    @Test func clamping() {
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .clamped(to: MessageIdentifierRange<UID>(654...655))
                == MessageIdentifierRange<UID>(654...655)
        )
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .clamped(to: MessageIdentifierRange<UID>(UID.min...UID.max))
                == MessageIdentifierRange<UID>(654...655)
        )
        #expect(
            MessageIdentifierRange<UID>(UID.min...UID.max)
                .clamped(to: MessageIdentifierRange<UID>(654...655))
                == MessageIdentifierRange<UID>(654...655)
        )
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .clamped(to: MessageIdentifierRange<UID>(100...200))
                == MessageIdentifierRange<UID>(200)
        )
    }

    @Test func overlaps() {
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .overlaps(MessageIdentifierRange<UID>(654...655))
        )
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .overlaps(MessageIdentifierRange<UID>(600...700))
        )
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .overlaps(MessageIdentifierRange<UID>(600...654))
        )
        #expect(
            MessageIdentifierRange<UID>(600...700)
                .overlaps(MessageIdentifierRange<UID>(654...655))
        )
        #expect(
            MessageIdentifierRange<UID>(654...655)
                .overlaps(MessageIdentifierRange<UID>(UID.min...UID.max))
        )
        #expect(
            !MessageIdentifierRange<UID>(100...600)
                .overlaps(MessageIdentifierRange<UID>(654...655))
        )
        #expect(
            !MessageIdentifierRange<UID>(654...655)
                .overlaps(MessageIdentifierRange<UID>(100...600))
        )
    }

    @Test func contains() {
        #expect(MessageIdentifierRange<UID>(654...655).contains(654))
        #expect(MessageIdentifierRange<UID>(654...655).contains(654))
        #expect(!MessageIdentifierRange<UID>(654...655).contains(653))
        #expect(!MessageIdentifierRange<UID>(654...655).contains(656))
        #expect(!MessageIdentifierRange<UID>(654...655).contains(UID.min))
        #expect(!MessageIdentifierRange<UID>(654...655).contains(UID.max))
    }

    @Test(arguments: [
        EncodeFixture.uidRange(33...44, "33:44"),
        EncodeFixture.uidRange(5, "5"),
        EncodeFixture.uidRange(MessageIdentifierRange<UID>(.max), "*"),
        EncodeFixture.uidRange(.all, "1:*"),
        EncodeFixture.uidRange(...55, "1:55"),
        EncodeFixture.uidRange(66..., "66:*"),
    ])
    func encode(_ fixture: EncodeFixture<MessageIdentifierRange<UID>>) {
        fixture.checkEncoding()
        #expect("\(fixture.input)" == fixture.expectedStrings.joined())
    }

    @Test func `range operator prefix`() {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let expected = "5:*"
        let size = buffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(5...(.max)))
        #expect(size == expected.utf8.count)
        var remaining = buffer
        let actualString = String(buffer: remaining.nextChunk().bytes)
        #expect(actualString == expected)
    }

    @Test func `range operator postfix`() {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let expected = "5:*"
        let size = buffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(5...(.max)))
        #expect(size == expected.utf8.count)
        var remaining = buffer
        let actualString = String(buffer: remaining.nextChunk().bytes)
        #expect(actualString == expected)
    }

    @Test func `range operator postfix complete right larger`() {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let expected = "44:55"
        let size = buffer.writeMessageIdentifierRange(MessageIdentifierRange<UID>(44...55))
        #expect(size == expected.utf8.count)
        var remaining = buffer
        let actualString = String(buffer: remaining.nextChunk().bytes)
        #expect(actualString == expected)
    }
}

// MARK: -

extension EncodeFixture<MessageIdentifierRange<UID>> {
    fileprivate static func uidRange(
        _ input: MessageIdentifierRange<UID>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageIdentifierRange($1) }
        )
    }
}
