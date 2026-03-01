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

@Suite("MetadataEntryName")
struct MetadataEntryNameTests {
    @Test("string init and round-trip")
    func stringInitAndRoundTrip() {
        let raw: String = "/private/vendor/example/color"
        let name = MetadataEntryName(raw)
        #expect(String(name) == "/private/vendor/example/color")
    }

    @Test("ByteBuffer init")
    func byteBufferInit() {
        let buf = ByteBuffer(string: "/shared/admin/quota")
        let name = MetadataEntryName(buf)
        #expect(String(name) == "/shared/admin/quota")
    }

    @Test("equality is based on content")
    func equalityIsBasedOnContent() {
        let a = MetadataEntryName("/private/comment")
        let b: MetadataEntryName = "/private/comment"
        #expect(a == b)
    }
}
