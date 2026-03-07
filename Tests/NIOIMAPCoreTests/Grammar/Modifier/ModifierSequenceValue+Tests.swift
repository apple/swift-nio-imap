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

@Suite("ModificationSequenceValue")
struct ModificationSequenceValueTests {
    @Test("lossy conversion from integer")
    func lossyConversionFromInteger() {
        #expect(ModificationSequenceValue(exactly: 0)?.value == 0)
        #expect(ModificationSequenceValue(exactly: 100 as Int64)?.value == 100)
        #expect(ModificationSequenceValue(exactly: 100 as UInt64)?.value == 100)
        #expect(ModificationSequenceValue(exactly: Int64.max)?.value == UInt64(Int64.max))

        #expect(ModificationSequenceValue(exactly: -1) == nil)
        #expect(ModificationSequenceValue(exactly: UInt64(Int64.max) + 1) == nil)
        #expect(ModificationSequenceValue(exactly: UInt64.max) == nil)
    }

    @Test("binary integer conversion")
    func binaryIntegerConversion() {
        let v = ModificationSequenceValue(integerLiteral: 42)
        #expect(Int(v) == 42)
        #expect(UInt64(v) == 42)
    }

    @Test("ordering operators")
    func orderingOperators() {
        let a = ModificationSequenceValue(integerLiteral: 10)
        let b = ModificationSequenceValue(integerLiteral: 20)
        #expect(a <= b)
        #expect(b <= b)
        #expect(!(b <= a))
    }

    @Test(arguments: [
        (ModificationSequenceValue(integerLiteral: 10), ModificationSequenceValue(integerLiteral: 20), true),
        (ModificationSequenceValue(integerLiteral: 20), ModificationSequenceValue(integerLiteral: 10), false),
        (ModificationSequenceValue(integerLiteral: 10), ModificationSequenceValue(integerLiteral: 10), false),
    ] as [(ModificationSequenceValue, ModificationSequenceValue, Bool)])
    func lessThanOperator(_ fixture: (ModificationSequenceValue, ModificationSequenceValue, Bool)) {
        #expect((fixture.0 < fixture.1) == fixture.2)
    }

    @Test("distance and advanced")
    func distanceAndAdvanced() {
        let start = ModificationSequenceValue(integerLiteral: 10)
        let end = ModificationSequenceValue(integerLiteral: 15)
        #expect(start.distance(to: end) == 5)
        #expect(end.distance(to: start) == -5)
        let advanced = start.advanced(by: 5)
        #expect(advanced == end)
    }

    #if swift(>=6.2)
    @Test("overflow triggers precondition failure") func overflowPreconditionFailure() async {
        await #expect(processExitsWith: ExitTest.Condition.failure, performing: {
            _ = ModificationSequenceValue(UInt64(Int64.max) + 1)
        })
    }
    #endif

    @Test(arguments: [
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 0), "0"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 1), "1"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 10), "10"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 100), "100"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 1000), "1000"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 5000), "5000"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 9999), "9999"),
        EncodeFixture.modificationSequenceValue(.init(integerLiteral: 10000), "10000"),
        EncodeFixture.modificationSequenceValue(ModificationSequenceValue(UInt64(Int64.max)), "\(Int64.max)"),
    ])
    func encode(_ fixture: EncodeFixture<ModificationSequenceValue>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.modificationSequenceValue("1", " ", expected: .success(1)),
        ParseFixture.modificationSequenceValue("123", " ", expected: .success(123)),
        ParseFixture.modificationSequenceValue("12345", " ", expected: .success(12345)),
        ParseFixture.modificationSequenceValue("1234567", " ", expected: .success(1_234_567)),
        ParseFixture.modificationSequenceValue("123456789", " ", expected: .success(123_456_789)),
        ParseFixture.modificationSequenceValue("0", " ", expected: .success(.zero)),
        ParseFixture.modificationSequenceValue(
            "9223372036854775807",
            " ",
            expected: .success(9_223_372_036_854_775_807)
        ),
        ParseFixture.modificationSequenceValue("9223372036854775808", " ", expected: .failure),
        ParseFixture.modificationSequenceValue("13853076851840262211", " ", expected: .failure),
        ParseFixture.modificationSequenceValue("18446744073709551615", " ", expected: .failure),
    ])
    func parse(_ fixture: ParseFixture<ModificationSequenceValue>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ModificationSequenceValue> {
    fileprivate static func modificationSequenceValue(
        _ input: ModificationSequenceValue,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeModificationSequenceValue($1) }
        )
    }
}

extension ParseFixture<ModificationSequenceValue> {
    fileprivate static func modificationSequenceValue(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseModificationSequenceValue
        )
    }
}
