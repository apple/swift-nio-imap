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

enum EncodeFixtureBufferKind: Hashable, Sendable {
    case client(CommandEncodingOptions)
    case server(ResponseEncodingOptions)
}

extension EncodeFixtureBufferKind {
    static var defaultServer: EncodeFixtureBufferKind { .server(ResponseEncodingOptions()) }
}

/// A fixture for testing IMAP encoding operations.
/// Captures the input value, encoding options, expected output, and encoder function.
struct EncodeFixture<T>: Sendable where T: Hashable, T: Sendable {
    var input: T
    var bufferKind: EncodeFixtureBufferKind = .defaultServer
    var expectedStrings: [String]
    var encoder: @Sendable (inout EncodeBuffer, T) -> Int
}

extension EncodeFixture {
    init(
        input: T,
        bufferKind: EncodeFixtureBufferKind = .defaultServer,
        expectedString: String,
        encoder: @escaping @Sendable (inout EncodeBuffer, T) -> Int
    ) {
        self.init(
            input: input,
            bufferKind: bufferKind,
            expectedStrings: [expectedString],
            encoder: encoder
        )
    }
}

extension EncodeFixture {
    /// Performs the encoding test by creating a buffer, encoding the input,
    /// and verifying the output matches expectations.
    func checkEncoding(
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var testBuffer: EncodeBuffer
        switch bufferKind {
        case .client(let options):
            testBuffer = EncodeBuffer.clientEncodeBuffer(
                buffer: ByteBufferAllocator().buffer(capacity: 128),
                options: options,
                loggingMode: false
            )
        case .server(let options):
            testBuffer = EncodeBuffer.serverEncodeBuffer(
                buffer: ByteBufferAllocator().buffer(capacity: 128),
                options: options,
                loggingMode: false
            )
        }

        let size = encoder(&testBuffer, input)

        // Extract encoded strings from buffer
        var remaining = testBuffer
        var chunk = remaining.nextChunk()
        var actualStrings: [String] = [String(buffer: chunk.bytes)]
        while chunk.waitForContinuation {
            chunk = remaining.nextChunk()
            actualStrings.append(String(buffer: chunk.bytes))
        }

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

extension EncodeFixture: CustomTestStringConvertible {
    var testDescription: String {
        expectedStrings.map { $0.mappingControlPictures() }.joined(separator: " ")
    }
}

extension EncodeFixture: CustomTestArgumentEncodable {
    func encodeTestArgument(to encoder: some Encoder) throws {
        // This is a bit of a hack.
        var c = encoder.unkeyedContainer()
        try c.encode(input.hashValue)
        try c.encode(bufferKind.hashValue)
    }
}

extension String {
    /// Maps control characters to their visual representations in the Control Pictures Unicode block.
    /// - 0x00-0x1F are mapped to U+2400-U+241F
    /// - 0x20 (space) is mapped to U+2423 (OPEN BOX)
    /// - All other characters pass through unchanged
    func mappingControlPictures() -> String {
        var result = ""
        for scalar in unicodeScalars {
            guard
                scalar.isASCII,
                scalar.value <= 0x20
            else {
                result.unicodeScalars.append(scalar)
                continue
            }
            if scalar.value == 0x20 {
                // Map space to OPEN BOX
                result.unicodeScalars.append(UnicodeScalar(0x2423)!)
            } else {
                // Map control characters to Control Pictures block
                result.unicodeScalars.append(UnicodeScalar(0x2400 + scalar.value)!)
            }
        }
        return result
    }
}
