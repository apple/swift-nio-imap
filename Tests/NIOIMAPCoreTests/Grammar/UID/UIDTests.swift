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

@Suite("UID")
struct UIDTests {
    @Test func `integer literal`() {
        let num: UID = 5
        #expect(num == 5)
    }

    @Test func `valid range`() {
        #expect(UID(exactly: 0) == nil)
        #expect(UID(exactly: 1)?.rawValue == 1)
        #expect(UID(exactly: 4_294_967_295)?.rawValue == 4_294_967_295)
        #expect(UID(exactly: 4_294_967_296) == nil)
    }

    @Test
    func comparable() {
        #expect((UID.max < UID.max) == false)
        #expect((UID.max < 999) == false)
        #expect(UID.max > 999)
        #expect(UID(1) < 999)
    }

    @Test(arguments: [
        DebugStringFixture(sut: UID.min, expected: "1"),
        DebugStringFixture(sut: UID.max, expected: "*"),
        DebugStringFixture(sut: UID(2), expected: "2"),
    ])
    func `custom debug string`(_ fixture: DebugStringFixture<UID>) {
        fixture.check()
    }

    @Test(arguments: [
        EncodeFixture.uid(.min, "1"),
        EncodeFixture.uid(.max, "*"),
        EncodeFixture.uid(UID(1234), "1234"),
        EncodeFixture.uid(UID(392_972_163), "392972163"),
    ])
    func encode(_ fixture: EncodeFixture<UID>) {
        fixture.checkEncoding()
    }

    @Test func `round trip codable`() {
        checkCodableRoundTrips(UID(1))
        checkCodableRoundTrips(UID(45_678))
        checkCodableRoundTrips(UID.max)
    }

    @Test func `strideable advanced by`() {
        #expect(UID(1).advanced(by: 1) == UID(2))
        #expect(UID(1).advanced(by: 2) == UID(3))
        #expect(UID.max.advanced(by: 0) == UID.max)
        #expect(UID.min.advanced(by: UID.min.distance(to: UID.max)) == UID.max)
        #expect(UID.max.advanced(by: UID.max.distance(to: UID.min)) == UID.min)
    }
}

// MARK: -

extension EncodeFixture<UID> {
    fileprivate static func uid(
        _ input: UID,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageIdentifier($1) }
        )
    }
}
