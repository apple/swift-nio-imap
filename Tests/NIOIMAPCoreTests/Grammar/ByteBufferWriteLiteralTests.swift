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

@Suite("ByteBuffer Literal Writing")
struct ByteBufferWriteLiteralTests {
    @Test(
        "writeIMAPString with client buffers",
        arguments: [
            EncodeFixture.imapStringClient("", expectedStrings: ["\"\""], options: .rfc3501),
            EncodeFixture.imapStringClient("", expectedStrings: ["{0}\r\n"], options: .noQuoted),
            EncodeFixture.imapStringClient("a", expectedStrings: [#""a""#], options: .rfc3501),
            EncodeFixture.imapStringClient("a", expectedStrings: [#""a""#], options: .literalPlus),
            EncodeFixture.imapStringClient("abc", expectedStrings: [#""abc""#], options: .rfc3501),
            // Spaces are ok:
            EncodeFixture.imapStringClient("a b c", expectedStrings: [#""a b c""#], options: .rfc3501),
            /// We'll use quoted-string even if the input contains `\` and `"`, but those then need to be escaped.
            EncodeFixture.imapStringClient(#"""#, expectedStrings: [#""\"""#], options: .rfc3501),
            EncodeFixture.imapStringClient(#"""#, expectedStrings: [#""\"""#], options: .literalPlus),
            EncodeFixture.imapStringClient(#"\"#, expectedStrings: [#""\\""#], options: .rfc3501),
            EncodeFixture.imapStringClient(#"\"#, expectedStrings: [#""\\""#], options: .literalPlus),
            EncodeFixture.imapStringClient(#"a\b"#, expectedStrings: [#""a\\b""#], options: .rfc3501),
            EncodeFixture.imapStringClient(#"a\b"#, expectedStrings: [#""a\\b""#], options: .literalPlus),
            EncodeFixture.imapStringClient(#"a"b"#, expectedStrings: [#""a\"b""#], options: .rfc3501),
            EncodeFixture.imapStringClient(#"a"b"#, expectedStrings: [#""a\"b""#], options: .literalPlus),
            EncodeFixture.imapStringClient(#"a"b\c"#, expectedStrings: [#""a\"b\\c""#], options: .rfc3501),
            EncodeFixture.imapStringClient(#"a"b\c"#, expectedStrings: [#""a\"b\\c""#], options: .literalPlus),
            /// But we'll fall back to literals if there are too many `\` and/or `"` in the string:
            EncodeFixture.imapStringClient(
                #"a""""b\\\\c"#,
                expectedStrings: ["{11}\r\n", #"a""""b\\\\c"#],
                options: .rfc3501
            ),
            // We'll use literal (plus) if the string contains any non-ASCII:
            EncodeFixture.imapStringClient("båd", expectedStrings: ["{4+}\r\nbåd"], options: .literalPlus),
            EncodeFixture.imapStringClient("パリ", expectedStrings: ["{6+}\r\nパリ"], options: .literalPlus),
            // Will also use literals if there are any control characters in the string:
            EncodeFixture.imapStringClient("a\u{007}b", expectedStrings: ["{3+}\r\na\u{007}b"], options: .literalPlus),
            EncodeFixture.imapStringClient("a\nb", expectedStrings: ["{3+}\r\na\nb"], options: .literalPlus),
            /// If the string is very long, we'll always use literals:
            EncodeFixture.imapStringClient(
                "01234567890123456789012345678901234567890123456789012345678901234567890",
                expectedStrings: [
                    "{71}\r\n", "01234567890123456789012345678901234567890123456789012345678901234567890",
                ],
                options: .rfc3501
            ),
            EncodeFixture.imapStringClient(
                String(repeating: "a", count: 100),
                expectedStrings: ["{100+}\r\n" + String(repeating: "a", count: 100)],
                options: .literalMinus
            ),
            EncodeFixture.imapStringClient(
                String(repeating: "a", count: 4096),
                expectedStrings: ["{4096+}\r\n" + String(repeating: "a", count: 4096)],
                options: .literalMinus
            ),
            EncodeFixture.imapStringClient(
                String(repeating: "a", count: 4097),
                expectedStrings: ["{4097}\r\n", String(repeating: "a", count: 4097)],
                options: .literalMinus
            ),
        ]
    )
    func writeIMAPStringWithClientBuffers(_ fixture: EncodeFixture<ByteBuffer>) {
        fixture.checkEncoding()
    }

    @Test(
        "writeIMAPString with server buffers",
        arguments: [
            EncodeFixture.imapStringServer("", expectedString: "\"\"", options: .rfc3501),
            EncodeFixture.imapStringServer("abc", expectedString: #""abc""#, options: .rfc3501),
            EncodeFixture.imapStringServer(#"""#, expectedString: #""\"""#, options: .rfc3501),
            EncodeFixture.imapStringServer(#"\"#, expectedString: #""\\""#, options: .rfc3501),
            EncodeFixture.imapStringServer(#"\""#, expectedString: #""\\\"""#, options: .rfc3501),
            EncodeFixture.imapStringServer(
                #"a""""b\\\\c"#,
                expectedString: #"{11}\#r\#na""""b\\\\c"#,
                options: .rfc3501
            ),
            EncodeFixture.imapStringServer("a", expectedString: "\"a\"", options: .rfc3501),
            EncodeFixture.imapStringServer("båd", expectedString: "{4}\r\nbåd", options: .rfc3501),
            EncodeFixture.imapStringServer("パリ", expectedString: "{6}\r\nパリ", options: .rfc3501),
            EncodeFixture.imapStringServer(
                "01234567890123456789012345678901234567890123456789012345678901234567890",
                expectedString: "{71}\r\n01234567890123456789012345678901234567890123456789012345678901234567890",
                options: .rfc3501
            ),
        ]
    )
    func writeIMAPStringWithServerBuffers(_ fixture: EncodeFixture<ByteBuffer>) {
        fixture.checkEncoding()
    }

    @Test(
        "writeLiteral8 with client buffers",
        arguments: [
            EncodeFixture.literal8("", expectedStrings: ["~{0}\r\n"], options: .rfc3501),
            EncodeFixture.literal8("abc", expectedStrings: ["~{3}\r\n", "abc"], options: .rfc3501),
        ]
    )
    func writeLiteral8WithClientBuffers(_ fixture: EncodeFixture<ByteBuffer>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ByteBuffer> {
    fileprivate static func imapStringClient(
        _ input: String,
        expectedStrings: [String],
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        EncodeFixture(
            input: ByteBuffer(string: input),
            bufferKind: .client(options),
            expectedStrings: expectedStrings,
            encoder: { $0.writeIMAPString($1) }
        )
    }

    fileprivate static func literal8(
        _ input: ByteBuffer,
        expectedStrings: [String],
        options: CommandEncodingOptions
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .client(options),
            expectedStrings: expectedStrings,
            encoder: { $0.writeLiteral8($1.readableBytesView) }
        )
    }

    fileprivate static func imapStringServer(
        _ input: String,
        expectedString: String,
        options: ResponseEncodingOptions = ResponseEncodingOptions()
    ) -> Self {
        EncodeFixture(
            input: ByteBuffer(string: input),
            bufferKind: .server(options),
            expectedString: expectedString,
            encoder: { $0.writeIMAPString($1) }
        )
    }
}
