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
    @Test func `lossy conversion from integer`() {
        #expect(ModificationSequenceValue(exactly: 0)?.value == 0)
        #expect(ModificationSequenceValue(exactly: 100 as Int64)?.value == 100)
        #expect(ModificationSequenceValue(exactly: 100 as UInt64)?.value == 100)
        #expect(ModificationSequenceValue(exactly: Int64.max)?.value == UInt64(Int64.max))

        #expect(ModificationSequenceValue(exactly: -1) == nil)
        #expect(ModificationSequenceValue(exactly: UInt64(Int64.max) + 1) == nil)
        #expect(ModificationSequenceValue(exactly: UInt64.max) == nil)
    }

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
