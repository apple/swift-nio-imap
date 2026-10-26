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

// MARK: - Parser input

extension TestUtilities {
    /// Runs `body` with a cursor over `text`.
    ///
    /// A cursor cannot be stored in a variable — it is non-escapable, which is what stops the parser
    /// from keeping input bytes past the call — so every test that used to build one and then read
    /// from it takes this closure form instead.
    ///
    /// The text is held in an array, which cannot vouch for its bytes, so a large extraction copies.
    ///
    /// - Parameters:
    ///   - text: The bytes to read.
    ///   - body: What to read with.
    static func withParseInput<R>(
        for text: String,
        _ body: (inout ParseInput) throws -> R
    ) rethrows -> R {
        try Array(text.utf8).withParseInput(limit: .max, body)
    }

    /// Runs `body` with a cursor over `string + terminator`, then checks what it left unconsumed.
    ///
    /// The input is padded on both sides — bytes before the first visible byte and after the last —
    /// so that a parser which reads outside the region it was given is caught rather than silently
    /// right. An `ArraySlice` is how that padding is expressed: the bytes are there, in the same
    /// allocation, and the region the parser sees is a slice that excludes them.
    static func withParseInput(
        _ string: String,
        terminator: String = "",
        shouldRemainUnchanged: Bool = false,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: (inout ParseInput) throws -> Void
    ) {
        let padded = Array("hello\(string)\(terminator)hallo".utf8)
        let inputBuffer = padded[5..<(padded.count - 5)]

        let expectedRemainder = shouldRemainUnchanged ? string + terminator : terminator

        inputBuffer.withParseInput(limit: .max) { input in
            if let error = errorThrown(by: { try body(&input) }) {
                Issue.record(error, "Parsing should not throw", sourceLocation: sourceLocation)
            }
            let remaining = (try? input.extractBytes(length: input.remaining)) ?? []
            #expect(
                String(decoding: remaining, as: UTF8.self) == expectedRemainder,
                sourceLocation: sourceLocation
            )
        }
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

// The parsers consume from an `IMAPInputBuffer`, which the tests spell as a string literal the way they
// used to spell a `ByteBuffer`.
extension IMAPInputBuffer {
    /// Creates a buffer holding `text`'s UTF-8 bytes as one region.
    init(_ text: String) {
        self.init()
        self.append(Array(text.utf8))
    }

    /// Creates a buffer holding `bytes` as one region.
    init(_ bytes: [UInt8]) {
        self.init()
        self.append(bytes)
    }

    /// Adds `text`'s UTF-8 bytes as another region — one more "network read".
    mutating func append(_ text: String) {
        self.append(Array(text.utf8))
    }
}

extension IMAPInputBuffer: ExpressibleByUnicodeScalarLiteral {}
extension IMAPInputBuffer: ExpressibleByExtendedGraphemeClusterLiteral {}
extension IMAPInputBuffer: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension IMAPInputBuffer {
    /// The bytes still waiting to be parsed, decoded as UTF-8.
    ///
    /// For asserting what a parser left behind. `IMAPInputBuffer` is deliberately not `Equatable` — it
    /// holds a queue of regions, and two buffers over the same bytes need not be split the same way — so
    /// tests compare this instead.
    var remainingText: String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(count)
        for region in byteRegions {
            bytes.append(contentsOf: region.copiedBytes())
        }
        return String(decoding: bytes, as: UTF8.self)
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
        var encodeBuffer = EncodeBuffer.serverEncodeBuffer(options: ResponseEncodingOptions(), loggingMode: false)
        _ = encoder(&encodeBuffer, value)
        let encoded = encodeBuffer.nextChunk().bytes.copiedBytes() + Array(terminator.utf8)
        let encodedString = String(decoding: encoded, as: UTF8.self)
        do {
            try encoded.withParseInput(limit: .max) { input in
                let parsed = try parser(&input, .testTracker)
                #expect(
                    parsed == value,
                    "Encoded as \(String(reflecting: encodedString))",
                    sourceLocation: sourceLocation
                )
                #expect(
                    input.remaining == terminator.utf8.count,
                    "Trailing bytes after parsing \(String(reflecting: encodedString))",
                    sourceLocation: sourceLocation
                )
            }
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

// Encoded chunks are `IMAPBufferList`s. This mirrors NIO's `String(buffer:)` so a test can read a
// chunk the same way it used to read a `ByteBuffer`.
extension String {
    init(buffer list: IMAPBufferList) {
        self = String(decoding: list.copiedBytes(), as: UTF8.self)
    }
}

// Encoded chunks are compared against string literals in a few places. A literal makes a one-region
// list, and `IMAPBufferList` equality is byte-wise, so it matches however the sink split the bytes up.
extension IMAPBufferList: ExpressibleByUnicodeScalarLiteral {}
extension IMAPBufferList: ExpressibleByExtendedGraphemeClusterLiteral {}
extension IMAPBufferList: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = IMAPBufferList(IMAPBuffer(Array(value.utf8)))
    }
}
