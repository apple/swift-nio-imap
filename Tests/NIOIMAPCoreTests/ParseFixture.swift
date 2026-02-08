//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

/// A fixture for testing IMAP parsing.
/// Captures the input value, encoding options, expected output, and encoder function.
struct ParseFixture<T>: Sendable where T: Sendable {
    var input: String
    var terminator: String
    var expected: Expected
    var parser: @Sendable (inout ParseBuffer, StackTracker) throws -> T
    
    enum Expected: Sendable {
        /// The input is valid.
        case success(T)
        /// The input is valid, but only a partial message. Waiting for more input.
        case incompleteMessage
        /// The input is invalid.
        case failure
    }
}

// MARK: -

extension ParseFixture: CustomTestArgumentEncodable {
    func encodeTestArgument(to encoder: some Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(input)
        try c.encode(terminator)
    }
}

extension ParseFixture: CustomTestStringConvertible {
    var testDescription: String {
        (input + terminator).mappingControlPictures()
    }
}

extension ParseFixture {
    func checkParsing(
        sourceLocation: SourceLocation = #_sourceLocation
    ) where T: Equatable {
        switch expected {
        case .success(let expectedValue):
            ParseBuffer.withBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: false,
                sourceLocation: sourceLocation
            ) { buffer in
                #expect(
                    throws: Never.self,
                    sourceLocation: sourceLocation,
                    performing: {
                        let parsed = try parser(&buffer, .testTracker)
                        #expect(
                            parsed ==
                            expectedValue,
                            sourceLocation: sourceLocation
                        )
                    }
                )
            }
        case .incompleteMessage:
            ParseBuffer.withBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                sourceLocation: sourceLocation
            ) { buffer in
                #expect(
                    throws: IncompleteMessage.self,
                    "The input buffer is incomplete. Should throw IncompleteMessage.",
                    sourceLocation: sourceLocation,
                    performing: {
                        try parser(&buffer, .testTracker)
                    }
                )
            }
        case .failure:
            ParseBuffer.withBuffer(
                input,
                terminator: terminator,
                shouldRemainUnchanged: true,
                sourceLocation: sourceLocation
            ) { buffer in
                #expect(
                    "Parsing should throw an error",
                    sourceLocation: sourceLocation,
                    performing: {
                        try parser(&buffer, .testTracker)
                    },
                    throws: { _ in true }
                )
            }
        }
    }
}

extension ParseBuffer {
    static func withBuffer(
        _ string: String,
        terminator: String,
        shouldRemainUnchanged: Bool,
        sourceLocation: SourceLocation,
        _ body: (inout ParseBuffer) -> Void
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
                #expect(String(buffer: beforeRunningBody) == remainingString, "Input buffer should remain unchanged.", sourceLocation: sourceLocation)
            } else {
                #expect(remainingString == expectedString, "Terminator should remain in input buffer, nothing else.", sourceLocation: sourceLocation)
            }
        }

        body(&parseBuffer)
    }
}
