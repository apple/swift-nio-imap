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
    @Test(
        arguments: [
            (MetadataEntryName("/private/vendor/example/color"), "/private/vendor/example/color"),
            (MetadataEntryName(ByteBuffer(string: "/shared/admin/quota")), "/shared/admin/quota"),
        ] as [(MetadataEntryName, String)]
    )
    func stringRoundTrip(_ fixture: (MetadataEntryName, String)) {
        #expect(String(fixture.0) == fixture.1)
    }

    @Test("equality is based on content")
    func equalityIsBasedOnContent() {
        let a = MetadataEntryName("/private/comment")
        let b: MetadataEntryName = "/private/comment"
        #expect(a == b)
    }

    @Test("init from String variable")
    func initFromStringVariable() {
        let a = "/private/variable"
        #expect(String(MetadataEntryName(a)) == "/private/variable")
    }
}
