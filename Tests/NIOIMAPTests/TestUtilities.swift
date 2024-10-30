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
import XCTest

enum TestUtilities {}

// MARK: - ByteBuffer

#if swift(>=5.3)
func magicFile(file: StaticString = (#filePath)) -> StaticString { file }
#else
func magicFile(file: StaticString = (#filePath)) -> StaticString { file }
#endif

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

    static func withBuffer(
        _ string: String,
        terminator: String = "",
        shouldRemainUnchanged: Bool = false,
        file: StaticString = (#filePath),
        line: UInt = #line,
        _ body: (inout ByteBuffer) throws -> Void
    ) {
        var inputBuffer = ByteBufferAllocator().buffer(capacity: string.utf8.count + terminator.utf8.count + 10)
        inputBuffer.writeString("hello")
        inputBuffer.moveReaderIndex(forwardBy: 5)
        inputBuffer.writeString(string)
        inputBuffer.writeString(terminator)
        inputBuffer.writeString("hallo")
        inputBuffer.moveWriterIndex(to: inputBuffer.writerIndex - 5)

        let expected = inputBuffer.getSlice(
            at: inputBuffer.readerIndex + string.utf8.count,
            length: terminator.utf8.count
        )!
        let beforeRunningBody = inputBuffer

        var parseBuffer = ParseBuffer(inputBuffer)

        defer {
            let remaining =
                (try? PL.parseBytes(
                    buffer: &parseBuffer,
                    tracker: .makeNewDefault,
                    upTo: .max
                )) ?? ByteBuffer()
            let expectedString = String(buffer: expected)
            let remainingString = String(buffer: remaining)
            if shouldRemainUnchanged {
                XCTAssertEqual(beforeRunningBody, inputBuffer, file: file, line: line)
            } else {
                XCTAssertEqual(remainingString, expectedString, file: file, line: line)
            }
        }

        XCTAssertNoThrow(try body(&inputBuffer), file: file, line: line)
    }
}

#if swift(>=5.8)
#if hasFeature(RetroactiveAttribute)
extension ByteBuffer: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let allocator = ByteBufferAllocator()
        self = allocator.buffer(capacity: 0)
        self.writeString(value)
    }
}
#else
extension ByteBuffer: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let allocator = ByteBufferAllocator()
        self = allocator.buffer(capacity: 0)
        self.writeString(value)
    }
}
#endif
#else
extension ByteBuffer: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let allocator = ByteBufferAllocator()
        self = allocator.buffer(capacity: 0)
        self.writeString(value)
    }
}
#endif
