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

@Suite("SequenceNumber")
struct SequenceNumberTests {}

extension SequenceNumberTests {
    @Test func `integer literal`() {
        let num: SequenceNumber = 5
        #expect(num == 5)
    }

    @Test func `valid range`() {
        #expect(SequenceNumber(exactly: 0) == nil)
        #expect(SequenceNumber(exactly: 1)?.rawValue == 1)
        #expect(SequenceNumber(exactly: 4_294_967_295)?.rawValue == 4_294_967_295)
        #expect(SequenceNumber(exactly: 4_294_967_296) == nil)
    }

    @Test func comparable() {
        #expect(!(SequenceNumber.max < .max))
        #expect(!(SequenceNumber.max < 999))
        #expect(SequenceNumber.max > 999)
        #expect(SequenceNumber(1) < 999)
    }

    @Test(arguments: [
        EncodeFixture.sequenceNumber(1, "1"),
        EncodeFixture.sequenceNumber(123, "123"),
        EncodeFixture.sequenceNumber(1234, "1234"),
        EncodeFixture.sequenceNumber(9999, "9999"),
        EncodeFixture.sequenceNumber(65535, "65535"),
        EncodeFixture.sequenceNumber(1_000_000, "1000000"),
        EncodeFixture.sequenceNumber(.max, "4294967295"),
    ])
    func encode(_ fixture: EncodeFixture<SequenceNumber>) {
        fixture.checkEncoding()
    }

    @Test func `advanced by`() {
        let min = SequenceNumber(1)
        let max = SequenceNumber.max
        #expect(max.advanced(by: 0) == max)
        #expect(min.advanced(by: min.distance(to: max)) == max)
        #expect(max.advanced(by: max.distance(to: min)) == min)
    }
}

// MARK: -

extension EncodeFixture<SequenceNumber> {
    fileprivate static func sequenceNumber(
        _ input: SequenceNumber,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSequenceNumber($1) }
        )
    }
}
