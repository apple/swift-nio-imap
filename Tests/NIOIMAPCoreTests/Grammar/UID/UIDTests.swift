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
    @Test("integer literal")
    func integerLiteral() {
        let num: UID = 5
        #expect(num == 5)
    }

    @Test("valid range")
    func validRange() {
        #expect(UID(exactly: 0) == nil)
        #expect(UID(exactly: 1)?.rawValue == 1)
        #expect(UID(exactly: 4_294_967_295)?.rawValue == 4_294_967_295)
        #expect(UID(exactly: 4_294_967_296) == nil)
    }

    @Test("comparable")
    func comparable() {
        #expect((UID.max < UID.max) == false)
        #expect((UID.max < 999) == false)
        #expect(UID.max > 999)
        #expect(UID(1) < 999)
    }

    @Test(
        "custom debug string",
        arguments: [
            DebugStringFixture(sut: UID.min, expected: "1"),
            DebugStringFixture(sut: UID.max, expected: "*"),
            DebugStringFixture(sut: UID(2), expected: "2"),
        ]
    )
    func customDebugString(_ fixture: DebugStringFixture<UID>) {
        fixture.check()
    }

    @Test(
        "encode",
        arguments: [
            EncodeFixture.uid(.min, "1"),
            EncodeFixture.uid(.max, "*"),
            EncodeFixture.uid(UID(1234), "1234"),
            EncodeFixture.uid(UID(392_972_163), "392972163"),
        ]
    )
    func encode(_ fixture: EncodeFixture<UID>) {
        fixture.checkEncoding()
    }

    @Test("round trip codable")
    func roundTripCodable() {
        checkCodableRoundTrips(UID(1))
        checkCodableRoundTrips(UID(45_678))
        checkCodableRoundTrips(UID.max)
    }

    @Test("strideable advanced by")
    func strideableAdvancedBy() {
        #expect(UID(1).advanced(by: 1) == UID(2))
        #expect(UID(1).advanced(by: 2) == UID(3))
        #expect(UID.max.advanced(by: 0) == UID.max)
        #expect(UID.min.advanced(by: UID.min.distance(to: UID.max)) == UID.max)
        #expect(UID.max.advanced(by: UID.max.distance(to: UID.min)) == UID.min)
    }

    @Test("conversion to UnknownMessageIdentifier")
    func conversionToUnknownMessageIdentifier() {
        let uid = UID(99)
        let unknown = UnknownMessageIdentifier(uid)
        #expect(unknown.rawValue == 99)
    }

    #if swift(>=6.2)
    @Test("advanced(by:) overflow triggers precondition failure") func advancedByOverflowPreconditionFailure() async {
        await #expect(
            processExitsWith: ExitTest.Condition.failure,
            performing: {
                _ = UID(1).advanced(by: Int64(UInt32.max) + 1)
            }
        )
    }
    #endif
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
