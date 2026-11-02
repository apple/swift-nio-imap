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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

/// The primitives that everything else in the encoder is composed from.
@Suite("EncodeBuffer primitives")
struct EncodeBufferPrimitivesTests {
    private func encoded(_ write: (inout EncodeBuffer) -> Int) -> (string: String, byteCount: Int) {
        var buffer = EncodeBuffer.clientEncodeBuffer(
            options: .rfc3501,
            loggingMode: false
        )
        let byteCount = write(&buffer)
        return (String(buffer: buffer.nextChunk().bytes), byteCount)
    }

    @Test("writeByte writes exactly one byte")
    func writeByte() {
        let result = encoded { $0.writeByte(UInt8(ascii: "*")) }
        #expect(result.string == "*")
        #expect(result.byteCount == 1)
    }

    @Test(
        "writeDecimal",
        arguments: [
            (0, "0"),
            (1, "1"),
            (9, "9"),
            (10, "10"),
            (99, "99"),
            (100, "100"),
            (1_234_567_890, "1234567890"),
            (Int.max, "9223372036854775807"),
            (-1, "-1"),
            (-42, "-42"),
            (Int.min, "-9223372036854775808"),
        ]
    )
    func writeDecimal(number: Int, expected: String) {
        let result = encoded { $0.writeDecimal(number) }
        #expect(result.string == expected)
        #expect(result.byteCount == expected.utf8.count)
    }

    @Test("writeDecimal covers the full unsigned range")
    func writeDecimalUnsigned() {
        #expect(encoded { $0.writeDecimal(UInt64.max) }.string == "18446744073709551615")
        #expect(encoded { $0.writeDecimal(UInt8.max) }.string == "255")
        #expect(encoded { $0.writeDecimal(UInt32.max) }.string == "4294967295")
    }

    @Test(
        "writeDecimal pads with leading zeros",
        arguments: [
            (0, 2, "00"),
            (7, 2, "07"),
            (7, 4, "0007"),
            (59, 2, "59"),
            // Padding never truncates: a number wider than `minimumDigits` is written in full.
            (1234, 2, "1234"),
            // The sign doesn't count towards the digits.
            (-7, 4, "-0007"),
        ]
    )
    func writeDecimalPadded(number: Int, minimumDigits: Int, expected: String) {
        let result = encoded { $0.writeDecimal(number, minimumDigits: minimumDigits) }
        #expect(result.string == expected)
        #expect(result.byteCount == expected.utf8.count)
    }

    @Test("writeDecimal pads a negative number to the largest allowed minimumDigits")
    func writeDecimalLargestPadding() {
        let minimumDigits = EncodeBuffer.maximumDecimalLength - 1
        let expected = "-" + String(repeating: "0", count: minimumDigits - 1) + "7"
        let result = encoded { $0.writeDecimal(-7, minimumDigits: minimumDigits) }
        #expect(result.string == expected)
        #expect(result.byteCount == EncodeBuffer.maximumDecimalLength)
    }

    @Test("maximumDecimalLength fits the widest magnitude plus a sign")
    func maximumDecimalLengthDerivation() {
        #expect(UInt128.bitWidth == EncodeBuffer.maximumDecimalBitWidth)
        #expect(String(UInt128.max).count + 1 == EncodeBuffer.maximumDecimalLength)
    }

    @Test("writeLiteralHeader")
    func writeLiteralHeader() {
        #expect(encoded { $0.writeLiteralHeader(byteCount: 0) }.string == "{0}\r\n")
        #expect(encoded { $0.writeLiteralHeader(byteCount: 123) }.string == "{123}\r\n")
        #expect(
            encoded { $0.writeLiteralHeader(byteCount: 123, synchronization: .nonSynchronizing) }.string == "{123+}\r\n"
        )
        #expect(encoded { $0.writeLiteralHeader(byteCount: 123, kind: .literal8) }.string == "~{123}\r\n")
        #expect(
            encoded { $0.writeLiteralHeader(byteCount: 123, synchronization: .nonSynchronizing, kind: .literal8) }
                .string
                == "~{123+}\r\n"
        )
    }

    @Test("writeRedactedByteCount")
    func writeRedactedByteCount() {
        #expect(encoded { $0.writeRedactedByteCount(0) }.string == "[0 bytes]")
        #expect(encoded { $0.writeRedactedByteCount(1_048_576) }.string == "[1048576 bytes]")
    }

    /// `writeQuotedIMAPString` stages the escaped form in a fixed-size buffer sized from the input, so
    /// the boundary cases are worth pinning: nothing to escape, everything to escape, and the largest
    /// input `shouldUseQuotedString` will accept.
    @Test("quoted strings are escaped in one write")
    func quotedStringEscaping() {
        #expect(encoded { $0.writeIMAPString("") }.string == #""""#)
        #expect(encoded { $0.writeIMAPString("abc") }.string == #""abc""#)
        #expect(encoded { $0.writeIMAPString(#"a"b"#) }.string == #""a\"b""#)
        #expect(encoded { $0.writeIMAPString(#"a\b"#) }.string == #""a\\b""#)
        // Five escapes is the most `shouldUseQuotedString` allows before falling back to a literal.
        let fiveQuotes = String(repeating: #"""#, count: 5)
        #expect(
            encoded { $0.writeIMAPString(fiveQuotes) }.string
                == #"""# + String(repeating: #"\""#, count: 5) + #"""#
        )
        let longest = String(repeating: "x", count: 70)
        #expect(encoded { $0.writeIMAPString(longest) }.string == "\"\(longest)\"")
    }
}

/// What `loggingMode` substitutes for payload bytes, at each site that substitutes something
/// different.
///
/// These pin *existing* behaviour rather than proposing any. The point is that the encoder does not do
/// one thing here, it does four, and the differences are not obvious from any single call site — so a
/// change to the primitives that quietly unified them would be a change to what gets written to a log
/// file, for exactly the payloads that most need keeping out of one.
@Suite("loggingMode redaction")
struct LoggingModeRedactionTests {
    /// Encodes in logging mode, draining every chunk — redacted literals still mark stop points, so
    /// reading one chunk would silently truncate.
    private func redacted(_ write: (inout EncodeBuffer) -> Void) -> String {
        var buffer = EncodeBuffer.clientEncodeBuffer(options: .rfc3501, loggingMode: true)
        write(&buffer)
        var bytes: [UInt8] = []
        while true {
            let chunk = buffer.nextChunk()
            bytes.append(contentsOf: chunk.bytes.copiedBytes())
            guard chunk.waitForContinuation else { break }
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    @Test("raw bytes become a byte count")
    func rawBytes() {
        #expect(redacted { $0.writeBytes([1, 2, 3]) } == "[3 bytes]")
        #expect(redacted { $0.writeBytes([]) } == "[0 bytes]")
        let payload = IMAPBuffer(Array(repeating: UInt8(0), count: 4096))
        #expect(redacted { $0.writeBytes(payload) } == "[4096 bytes]")
    }

    @Test("numbers and single bytes are not redacted, because they are not payload")
    func structuralBytesSurvive() {
        // Lengths, offsets and identifiers have to stay readable or a redacted log says nothing.
        #expect(redacted { $0.writeDecimal(1234) } == "1234")
        #expect(redacted { $0.writeByte(UInt8(ascii: "*")) } == "*")
        #expect(redacted { $0.writeLiteralHeader(byteCount: 99) } == "{99}\r\n")
    }

    @Test("an IMAP string becomes the empty-set sign, and keeps its real length")
    func imapString() {
        // Not `[N bytes]`: a string that would have been quoted is redacted as `"∅"`, and one that
        // would have been a literal keeps its header — so the shape of the command still reads
        // correctly — with the bytes replaced.
        #expect(redacted { $0.writeIMAPString("INBOX") } == #""∅""#)
        let long = String(repeating: "x", count: 100)
        #expect(redacted { $0.writeIMAPString(long) } == "{100}\r\n∅")
    }

    @Test("an APPEND message's bytes are dropped entirely, not counted")
    func appendMessageBytes() {
        // This one is the odd one out: `.messageBytes` returns early *before* reaching the primitive,
        // so nothing at all is written — not even a count.
        let description = CommandStreamPart.descriptionWithoutPII([
            .append(.messageBytes("secret message"))
        ])
        #expect(description == "")
    }

    @Test("the end of an APPEND message is marked, so a redacted log still shows the boundary")
    func appendEndMessage() {
        #expect(CommandStreamPart.descriptionWithoutPII([.append(.endMessage)]) == "∅")
    }

    @Test("catenated data is counted rather than dropped")
    func catenateData() {
        // Unlike `.messageBytes`, this has no early return, so it picks up the primitive's `[N bytes]`.
        let description = CommandStreamPart.descriptionWithoutPII([
            .append(.catenateData(.bytes("0123456789")))
        ])
        #expect(description == "[10 bytes]")
    }
}
