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

@Suite("UIDValidity")
struct UIDValidityTests {
    @Test("encode", arguments: [
        EncodeFixture.uidValidity(1, "1"),
        EncodeFixture.uidValidity(123, "123"),
        EncodeFixture.uidValidity(4_294_967_295, "4294967295"),
    ])
    func encode(_ fixture: EncodeFixture<UIDValidity>) {
        fixture.checkEncoding()
    }

    @Test("parse", arguments: [
        ParseFixture.uidValidity("1", " ", expected: .success(1)),
        ParseFixture.uidValidity("12", " ", expected: .success(12)),
        ParseFixture.uidValidity("123", " ", expected: .success(123)),
        ParseFixture.uidValidity("0", " ", expected: .failure),
        ParseFixture.uidValidity("1", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<UIDValidity>) {
        fixture.checkParsing()
    }

    @Test("valid range")
    func validRange() {
        #expect(UIDValidity(exactly: 0) == nil)
        #expect(UIDValidity(exactly: 1)?.rawValue == 1)
        #expect(UIDValidity(exactly: 4_294_967_295)?.rawValue == 4_294_967_295)
        #expect(UIDValidity(exactly: 4_294_967_296) == nil)
    }

    @Test("binary integer conversion")
    func binaryIntegerConversion() {
        let v: UIDValidity = 42
        #expect(Int(v) == 42)
        #expect(UInt64(v) == 42)
    }
}

// MARK: -

extension EncodeFixture<UIDValidity> {
    fileprivate static func uidValidity(_ input: UIDValidity, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUIDValidity($1) }
        )
    }
}

extension ParseFixture<UIDValidity> {
    fileprivate static func uidValidity(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUIDValidity
        )
    }
}
