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

@Suite("MessagePath.ByteRange")
struct MessagePathByteRangeTests {
    @Test(arguments: [
        EncodeFixture.messagePathByteRange(
            .init(range: .init(offset: 1, length: nil)),
            "/;PARTIAL=1"
        ),
        EncodeFixture.messagePathByteRange(
            .init(range: .init(offset: 1, length: 2)),
            "/;PARTIAL=1.2"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MessagePath.ByteRange>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture<MessagePath.ByteRange> {
    fileprivate static func messagePathByteRange(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeMessagePathByteRange($1) }
        )
    }
}
