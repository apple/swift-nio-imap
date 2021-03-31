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

extension TestUtilities {
    static func makeParseBuffer(for text: String) -> ParseBuffer {
        let buffer = ByteBuffer(string: text)
        return ParseBuffer(buffer)
    }

    static func withParseBuffer(_ string: String,
                                terminator: String = "",
                                shouldRemainUnchanged: Bool = false,
                                file: StaticString = (#file), line: UInt = #line, _ body: (inout ParseBuffer) throws -> Void)
    {
        var inputBuffer = ByteBufferAllocator().buffer(capacity: string.utf8.count + terminator.utf8.count + 10)
        inputBuffer.writeString("hello")
        inputBuffer.moveReaderIndex(forwardBy: 5)
        inputBuffer.writeString(string)
        inputBuffer.writeString(terminator)
        inputBuffer.writeString("hallo")
        inputBuffer.moveWriterIndex(to: inputBuffer.writerIndex - 5)

        let expected = inputBuffer.getSlice(at: inputBuffer.readerIndex + string.utf8.count, length: terminator.utf8.count)!
        let beforeRunningBody = inputBuffer

        var parseBuffer = ParseBuffer(inputBuffer)

        defer {
            let expectedString = String(buffer: expected)
            let remaining = (try? PL.parseBytes(buffer: &parseBuffer,
                                                tracker: .makeNewDefaultLimitStackTracker,
                                                upTo: .max)) ?? ByteBuffer()
            let remainingString = String(buffer: remaining)
            if shouldRemainUnchanged {
                XCTAssertEqual(String(buffer: beforeRunningBody), remainingString, file: file, line: line)
            } else {
                XCTAssertEqual(remainingString, expectedString, file: file, line: line)
            }
        }

        XCTAssertNoThrow(try body(&parseBuffer), file: file, line: line)
    }
}

extension ByteBuffer: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: Self.StringLiteralType) {
        let allocator = ByteBufferAllocator()
        self = allocator.buffer(capacity: 0)
        self.writeString(value)
    }
}

extension TestUtilities {
    static func roundTripCodable<A>(_ value: A) throws -> A where A: Codable {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        return try decoder.decode(A.self, from: encoder.encode(value))
    }
}
