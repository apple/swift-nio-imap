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

@testable import NIOIMAPCore
import Testing

@Suite("String + ByteBuffer")
struct StringByteBufferTests {
    @Test("validating UTF-8 returns nil for overflow bytes")
    func validatingUtf8ReturnsNilForOverflowBytes() {
        let bytes: [UInt8] = [0, 1, 2, 3, 255]
        #expect(String(validatingUTF8Bytes: bytes) == nil)
    }

    @Test(
        "validating UTF-8 returns nil for invalid sequences",
        arguments: [
            [0xC2],
            [0xE1, 0x80],
        ]
    )
    func validatingUtf8ReturnsNilForInvalidSequences(bytes: [UInt8]) {
        #expect(String(validatingUTF8Bytes: bytes) == nil)
    }

    @Test("validating UTF-8 correctly decodes valid string")
    func validatingUtf8CorrectlyDecodesValidString() {
        let test1 = "hello, world"
        #expect(String(validatingUTF8Bytes: test1.utf8) == test1)

        let test2: [UInt8] = [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4]
        #expect(String(validatingUTF8Bytes: test2) == "⚡⚢⚣⚤")
    }

    @Test("best effort decoding correctly decodes valid string")
    func bestEffortDecodingCorrectlyDecodesValidString() {
        let test1 = "hello, world"
        #expect(String(bestEffortDecodingUTF8Bytes: test1.utf8) == test1)

        let test2: [UInt8] = [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4]
        #expect(String(bestEffortDecodingUTF8Bytes: test2) == "⚡⚢⚣⚤")
    }

    @Test("best effort decoding removes invalid bytes")
    func bestEffortDecodingRemovesInvalidBytes() {
        let bytes: [UInt8] = [0x41, 0xFF, 0x42]
        #expect(String(bestEffortDecodingUTF8Bytes: bytes) == "AB")
    }
}
