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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ByteRange")
struct ByteRangeTests {
    @Test(arguments: [
        EncodeFixture.byteRange(0...199, "<0.200>"),
        EncodeFixture.byteRange(1...2, "<1.2>"),
        EncodeFixture.byteRange(10...20, "<10.11>"),
        EncodeFixture.byteRange(100...199, "<100.100>"),
        EncodeFixture.byteRange(400...479, "<400.80>"),
        EncodeFixture.byteRange(843...1_369, "<843.527>"),
    ])
    func `encode closed range`(_ fixture: EncodeFixture<ClosedRange<UInt32>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.byteRangeStruct(.init(offset: 1, length: nil), "1"),
        EncodeFixture.byteRangeStruct(.init(offset: 1, length: 2), "1.2"),
    ])
    func `encode ByteRange struct`(_ fixture: EncodeFixture<ByteRange>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ClosedRange<UInt32>> {
    fileprivate static func byteRange(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeByteRange($1) }
        )
    }
}

extension EncodeFixture<ByteRange> {
    fileprivate static func byteRangeStruct(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeByteRange($1) }
        )
    }
}
