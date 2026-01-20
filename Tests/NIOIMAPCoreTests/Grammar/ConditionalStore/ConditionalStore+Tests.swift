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

@Suite("ConditionalStoreParameter")
struct ConditionalStoreTests {
    @Test
    func `encodes to CONDSTORE`() {
        let expected = "CONDSTORE"
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        let size = buffer.writeConditionalStoreParameter()
        #expect(size == expected.utf8.count)
        let chunk = buffer.nextChunk()
        #expect(String(buffer: chunk.bytes) == expected)
    }
}
