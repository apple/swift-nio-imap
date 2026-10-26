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

import Foundation
import NIO
@testable import NIOIMAPCore
import Testing

enum TestUtilities {}

// MARK: - ByteBuffer

extension TestUtilities {
    static func makeParseBuffer(for bytes: [UInt8]) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        return buffer
    }

    static func makeParseBuffer(for text: String) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        return buffer
    }

}

// Model fields that used to be `ByteBuffer` are now `[UInt8]`, and the test suite spells hundreds of
// them as string literals. `IMAPBuffer` ships its own literal conformances; a byte array does not, so
// this is the test-only stand-in for the retroactive `ByteBuffer` conformance it replaces.
extension Array: @retroactive ExpressibleByUnicodeScalarLiteral where Element == UInt8 {}
extension Array: @retroactive ExpressibleByExtendedGraphemeClusterLiteral where Element == UInt8 {}
extension Array: @retroactive ExpressibleByStringLiteral where Element == UInt8 {
    public init(stringLiteral value: String) {
        self = Array(value.utf8)
    }
}
extension ByteBuffer: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = ByteBuffer(string: value)
    }
}

// Encoded chunks are `IMAPBufferList`s, and the state-machine tests spell the bytes they expect as
// string literals. A literal makes a one-region list; equality is byte-wise and ignores segmentation,
// so it compares equal to whatever the encoder's sink actually produced.
extension IMAPBufferList: ExpressibleByUnicodeScalarLiteral {}
extension IMAPBufferList: ExpressibleByExtendedGraphemeClusterLiteral {}
extension IMAPBufferList: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = IMAPBufferList(IMAPBuffer(Array(value.utf8)))
    }
}

extension String {
    init(buffer list: IMAPBufferList) {
        self = String(decoding: list.copiedBytes(), as: UTF8.self)
    }
}
