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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

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
        sourceLocation: SourceLocation = #_sourceLocation,
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
                #expect(String(buffer: beforeRunningBody) == remainingString, sourceLocation: sourceLocation)
            } else {
                #expect(remainingString == expectedString, sourceLocation: sourceLocation)
            }
        }

        #expect(
            throws: Never.self,
            sourceLocation: sourceLocation
        ) {
            try body(&parseBuffer)
        }
    }
}

extension ByteBuffer: @retroactive ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        let allocator = ByteBufferAllocator()
        self = allocator.buffer(capacity: 0)
        self.writeString(value)
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

extension CommandEncodingOptions {
    static var literalPlus: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useNonSynchronizingLiteralPlus = true
        return o
    }

    static var literalMinus: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useNonSynchronizingLiteralMinus = true
        return o
    }

    static var noQuoted: CommandEncodingOptions {
        var o = CommandEncodingOptions()
        o.useQuotedString = false
        return o
    }
}

extension ResponseEncodingOptions {
    static var rfc3501: ResponseEncodingOptions { ResponseEncodingOptions() }
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

extension StackTracker {
    static var testTracker: StackTracker {
        StackTracker(maximumParserStackDepth: 30)
    }
}

let CR = UInt8(ascii: "\r")
let LF = UInt8(ascii: "\n")
let CRLF = String(decoding: [CR, LF], as: Unicode.UTF8.self)

// MARK: - Round-trip

extension TestUtilities {
    /// Encodes `value` (server mode), parses the bytes back, and expects the original value.
    ///
    /// Catches both injection (bytes the parser reads differently) and encode/parse mismatches.
    static func expectRoundTrip<T: Equatable>(
        _ value: T,
        terminator: String = " ",
        encoder: (inout EncodeBuffer, T) -> Int,
        parser: (inout ParseBuffer, StackTracker) throws -> T,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        var encodeBuffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        _ = encoder(&encodeBuffer, value)
        var encoded = encodeBuffer.nextChunk().bytes
        encoded.writeString(terminator)
        let encodedString = String(buffer: encoded)
        var parseBuffer = ParseBuffer(encoded)
        do {
            let parsed = try parser(&parseBuffer, .testTracker)
            #expect(parsed == value, "Encoded as \(String(reflecting: encodedString))", sourceLocation: sourceLocation)
            #expect(
                parseBuffer.readableBytes == terminator.utf8.count,
                "Trailing bytes after parsing \(String(reflecting: encodedString))",
                sourceLocation: sourceLocation
            )
        } catch {
            Issue.record(
                "Failed to parse \(String(reflecting: encodedString)): \(error)",
                sourceLocation: sourceLocation
            )
        }
    }
}

// MARK: - Exit tests

#if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
extension TestUtilities {
    /// Expects an exit test to have trapped with `message` on standard error.
    ///
    /// The exit status alone can't show which check trapped: in debug, the `assert` in
    /// `init(unchecked:)` traps too, so a missing `precondition` in `init(stringLiteral:)` would
    /// pass unnoticed. Release builds drop both the `assert` and `precondition` messages, so the
    /// message is only checked in debug.
    static func expectTrapMessage(
        _ result: ExitTest.Result?,
        _ message: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #if DEBUG
        let standardError = String(decoding: result?.standardErrorContent ?? [], as: UTF8.self)
        #expect(standardError.contains(message), "\(standardError)", sourceLocation: sourceLocation)
        #endif
    }
}
#endif
