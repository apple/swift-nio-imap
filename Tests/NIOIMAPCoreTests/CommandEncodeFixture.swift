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

/// A fixture for testing IMAP command encoding operations (client-side).
/// Captures the input command, encoding options, expected output, and encoder function.
struct CommandEncodeFixture<T>: Sendable where T: Hashable, T: Sendable {
    var input: T
    var options: CommandEncodingOptions = CommandEncodingOptions()
    var expectedStrings: [String]
    var encoder: @Sendable (inout CommandEncodeBuffer, T) -> Int
}

extension CommandEncodeFixture {
    init(
        input: T,
        options: CommandEncodingOptions = CommandEncodingOptions(),
        expectedString: String,
        encoder: @escaping @Sendable (inout CommandEncodeBuffer, T) -> Int
    ) {
        self.init(
            input: input,
            options: options,
            expectedStrings: [expectedString],
            encoder: encoder
        )
    }
}

extension CommandEncodeFixture {
    /// Performs the encoding test by creating a buffer, encoding the input,
    /// and verifying the output matches expectations.
    func checkEncoding(
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var encodeBuffer = CommandEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: options,
            loggingMode: false
        )

        let size = encoder(&encodeBuffer, input)

        // Extract encoded strings from buffer
        let actualStrings: [String] = {
            var remaining: EncodeBuffer = encodeBuffer.buffer
            var chunk = remaining.nextChunk()
            var result: [String] = [String(buffer: chunk.bytes)]
            while chunk.waitForContinuation {
                chunk = remaining.nextChunk()
                result.append(String(buffer: chunk.bytes))
            }
            return result
        }()

        // Verify byte count
        let expectedByteCount = expectedStrings.reduce(0) { $0 + $1.utf8.count }
        #expect(
            size == expectedByteCount,
            "Expected byte count to match",
            sourceLocation: sourceLocation
        )

        // Verify encoded strings
        #expect(
            actualStrings.map { $0.mappingControlPictures() } == expectedStrings.map { $0.mappingControlPictures() },
            "Expected encoded strings to match",
            sourceLocation: sourceLocation
        )
    }
}

extension CommandEncodeFixture: CustomTestStringConvertible {
    var testDescription: String {
        expectedStrings.map { $0.mappingControlPictures() }.joined(separator: " ")
    }
}

extension CommandEncodeFixture: CustomTestArgumentEncodable {
    func encodeTestArgument(to encoder: some Encoder) throws {
        // This is a bit of a hack.
        var c = encoder.unkeyedContainer()
        try c.encode(input.hashValue)
        try c.encode(options.hashValue)
    }
}
