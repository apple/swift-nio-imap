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

@Suite("BodyStructure.Encoding")
struct BodyFieldEncodingTests {
    @Test(
        "encoding",
        arguments: [
            EncodeFixture.bodyEncoding(.sevenBit, #""7BIT""#),
            EncodeFixture.bodyEncoding(.eightBit, #""8BIT""#),
            EncodeFixture.bodyEncoding(.binary, #""BINARY""#),
            EncodeFixture.bodyEncoding(.base64, #""BASE64""#),
            EncodeFixture.bodyEncoding(.quotedPrintable, #""QUOTED-PRINTABLE""#),
            EncodeFixture.bodyEncoding(.init("some"), "\"SOME\""),
            // Must be escaped / a literal, not spliced into `"…"`:
            EncodeFixture.bodyEncoding(.init(#"x" 0 0) UID 9 ("#), #""X\" 0 0) UID 9 (""#),
            EncodeFixture.bodyEncoding(.init(#"a\b"#), #""A\\B""#),
            EncodeFixture.bodyEncoding(.init("x\r\n* BYE"), "{8}\r\nX\r\n* BYE"),
        ]
    )
    func encoding(_ fixture: EncodeFixture<BodyStructure.Encoding>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.bodyEncoding(#""BASE64""#, expected: .success(.base64)),
            ParseFixture.bodyEncoding(#""BINARY""#, expected: .success(.binary)),
            ParseFixture.bodyEncoding(#""7BIT""#, expected: .success(.sevenBit)),
            ParseFixture.bodyEncoding(#""8BIT""#, expected: .success(.eightBit)),
            ParseFixture.bodyEncoding(#""QUOTED-PRINTABLE""#, expected: .success(.quotedPrintable)),
            ParseFixture.bodyEncoding(#""other""#, expected: .success(.init("other"))),
        ]
    )
    func parse(_ fixture: ParseFixture<BodyStructure.Encoding?>) {
        fixture.checkParsing()
    }

    @Test(
        "encode/parse round-trip",
        arguments: ["7BIT", "QUOTED-PRINTABLE", "SOME", #"X" 0 0) UID 9 ("#, #"A\B"#, "X\r\n* BYE"]
    )
    func roundTrip(_ value: String) {
        TestUtilities.expectRoundTrip(
            BodyStructure.Encoding(value),
            encoder: { $0.writeBodyEncoding($1) },
            parser: GrammarParser().parseBodyEncoding
        )
    }

    @Test("nil encoding encodes as NIL")
    func nilEncodingEncodesAsNIL() {
        let expected = "NIL"
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 32),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        _ = buffer.writeBodyEncoding(nil)
        var remaining = buffer
        let chunk = remaining.nextChunk()
        #expect(String(buffer: chunk.bytes) == expected)
    }

    @Test("debug description")
    func debugDescription() {
        #expect(BodyStructure.Encoding.sevenBit.debugDescription == "7BIT")
        #expect(BodyStructure.Encoding.base64.debugDescription == "BASE64")
    }

    @Test("string conversion")
    func stringConversion() {
        #expect(String(BodyStructure.Encoding.sevenBit) == "7BIT")
        #expect(String(BodyStructure.Encoding.quotedPrintable) == "QUOTED-PRINTABLE")
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.Encoding> {
    fileprivate static func bodyEncoding(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyEncoding($1) }
        )
    }
}

extension ParseFixture<BodyStructure.Encoding?> {
    fileprivate static func bodyEncoding(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyEncoding
        )
    }
}
