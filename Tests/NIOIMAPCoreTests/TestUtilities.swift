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
import XCTest

func expectEqualAndEqualHash<T>(
    _ a: T,
    _ b: T,
    sourceLocation: SourceLocation = #_sourceLocation
) where T: Hashable {
    func hash(_ value: T) -> Int {
        var hasher = Hasher()
        value.hash(into: &hasher)
        return hasher.finalize()
    }
    #expect(a == b, sourceLocation: sourceLocation)
    #expect(a.hashValue == b.hashValue, sourceLocation: sourceLocation)
    #expect(hash(a) == hash(b), sourceLocation: sourceLocation)
}

enum TestUtilities {}

// MARK: - ByteBuffer

extension TestUtilities {
    static func makeParseBuffer(for text: String) -> ParseBuffer {
        let buffer = ByteBuffer(string: text)
        return ParseBuffer(buffer)
    }

    static func withParseBuffer(
        _ string: String,
        terminator: String = "",
        shouldRemainUnchanged: Bool = false,
        file: StaticString = (#filePath),
        line: UInt = #line,
        _ body: (inout ParseBuffer) throws -> Void
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
            let expectedString = String(buffer: expected)
            let remaining =
                (try? PL.parseBytes(
                    buffer: &parseBuffer,
                    tracker: .makeNewDefault,
                    upTo: .max
                )) ?? ByteBuffer()
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

extension TestUtilities {
    @available(*, deprecated, message: "Use checkCodableRoundTrips() instead.")
    static func roundTripCodable<A>(_ value: A) throws -> A where A: Codable {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        return try decoder.decode(A.self, from: encoder.encode(value))
    }
}

func checkCodableRoundTrips<A>(
    _ a: A,
    sourceLocation: SourceLocation = #_sourceLocation
) where A: Codable, A: Equatable {
    let encoder = JSONEncoder()
    let data: Data
    do {
        data = try encoder.encode(a)
    } catch {
        Issue.record("Failed to encode: \(error)", sourceLocation: sourceLocation)
        return
    }
    let decoder = JSONDecoder()
    let decoded: A
    do {
        decoded = try decoder.decode(A.self, from: data)
    } catch {
        Issue.record("Failed to decode: \(error)", sourceLocation: sourceLocation)
        return
    }
    #expect(decoded == a, sourceLocation: sourceLocation)
}
