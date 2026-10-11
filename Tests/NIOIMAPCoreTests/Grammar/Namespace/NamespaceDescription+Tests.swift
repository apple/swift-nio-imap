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
import OrderedCollections
import Testing

@Suite("NamespaceDescription")
struct NamespaceDescriptionTests {
    @Test(arguments: [
        EncodeFixture.namespaceDescription(
            try! .init(string: "string", delimiter: nil, responseExtensions: [:]),
            "(\"string\" NIL)"
        ),
        EncodeFixture.namespaceDescription(
            try! .init(string: "string", delimiter: "a", responseExtensions: [:]),
            "(\"string\" \"a\")"
        ),
        EncodeFixture.namespaceDescription(
            try! .init(string: "string", delimiter: nil, responseExtensions: ["str2": ["str3"]]),
            "(\"string\" NIL \"str2\" (\"str3\"))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NamespaceDescription>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode escapes quoted-specials",
        arguments: [
            ("\\", #"("x" "\\")"#),
            ("\"", #"("x" "\"")"#),
        ] as [(Character, String)]
    )
    func encodeQuotedSpecial(_ delimiter: Character, _ expected: String) throws {
        EncodeFixture(
            input: try NamespaceDescription(string: "x", delimiter: delimiter, responseExtensions: [:]),
            bufferKind: .defaultServer,
            expectedString: expected,
            encoder: { $0.writeNamespaceDescription($1) }
        ).checkEncoding()
    }

    /// The delimiter isn't PII, so logging shows it.
    @Test("logging mode shows the delimiter")
    func loggingMode() throws {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBuffer(),
            options: ResponseEncodingOptions(),
            loggingMode: true
        )
        buffer.writeNamespaceDescription(
            try NamespaceDescription(string: "x", delimiter: "/", responseExtensions: [:])
        )
        #expect(String(buffer: buffer.nextChunk().bytes).hasSuffix(#" "/")"#))
    }

    /// `DQUOTE QUOTED-CHAR DQUOTE`: CR, LF, NUL, and non-ASCII can't be written.
    @Test(
        "invalid delimiter throws",
        arguments: ["\r", "\n", "\r\n", "\0", "ü", "🇨🇭"] as [Character]
    )
    func invalidDelimiter(_ delimiter: Character) {
        #expect(throws: NamespaceDescription.InvalidDelimiterError(delimiter: delimiter)) {
            try NamespaceDescription(string: "x", delimiter: delimiter, responseExtensions: [:])
        }
    }

    /// Every delimiter we accept has to parse back unchanged.
    @Test(
        "delimiter round-trips",
        arguments: [nil, "/", ".", "\\", "\"", "~", "\t", " ", "\u{7F}"] as [Character?]
    )
    func delimiterRoundTrip(_ delimiter: Character?) throws {
        let description = try NamespaceDescription(string: "x", delimiter: delimiter, responseExtensions: [:])
        #expect(description.delimiter == delimiter)
        TestUtilities.expectRoundTrip(
            description,
            encoder: { $0.writeNamespaceDescription($1) },
            parser: GrammarParser().parseNamespaceDescription
        )
    }

    @Test(arguments: [
        ParseFixture.namespaceDescription(
            "(\"str1\" NIL)",
            " ",
            expected: .success(try! .init(string: "str1", delimiter: nil, responseExtensions: [:]))
        ),
        ParseFixture.namespaceDescription(
            "(\"str\" \"a\")",
            " ",
            expected: .success(try! .init(string: "str", delimiter: "a", responseExtensions: [:]))
        ),
        ParseFixture.namespaceDescription(
            "(\"str\" \"\r\")",
            " ",
            expected: .failureIgnoringBufferModifications
        ),
        // Escaped quoted-specials: `"\\"` is a backslash, `"\""` a double quote.
        ParseFixture.namespaceDescription(
            #"("str" "\\")"#,
            " ",
            expected: .success(try! .init(string: "str", delimiter: "\\", responseExtensions: [:]))
        ),
        ParseFixture.namespaceDescription(
            #"("str" "\"")"#,
            " ",
            expected: .success(try! .init(string: "str", delimiter: "\"", responseExtensions: [:]))
        ),
        ParseFixture.namespaceDescription(#"("str" "\a")"#, " ", expected: .failureIgnoringBufferModifications),
        ParseFixture.namespaceDescription(
            "(\"str\" NIL \"ext-key\" (\"val1\" \"val2\"))",
            " ",
            expected: .success(
                try! .init(
                    string: "str",
                    delimiter: nil,
                    responseExtensions: ["ext-key": ["val1", "val2"]]
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<NamespaceDescription>) {
        fixture.checkParsing()
    }

    @Test(
        "parse NAMESPACE",
        arguments: [
            ParseFixture.namespace(
                "NIL",
                expected: .success([])
            ),
            ParseFixture.namespace(
                "((\"#mh/\" \"/\"))",
                expected: .success([try! .init(string: "#mh/", delimiter: "/", responseExtensions: [:])])
            ),
            ParseFixture.namespace(
                "((\"\" \"/\")(\"#mh/\" \"/\"))",
                expected: .success([
                    try! .init(string: "", delimiter: "/", responseExtensions: [:]),
                    try! .init(string: "#mh/", delimiter: "/", responseExtensions: [:]),
                ])
            ),
            ParseFixture.namespace("", "", expected: .incompleteMessage),
        ]
    )
    func parseNamespace(_ fixture: ParseFixture<[NamespaceDescription]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<NamespaceDescription> {
    fileprivate static func namespaceDescription(
        _ input: NamespaceDescription,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNamespaceDescription($1) }
        )
    }
}

extension ParseFixture<NamespaceDescription> {
    fileprivate static func namespaceDescription(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNamespaceDescription
        )
    }
}

extension ParseFixture<[NamespaceDescription]> {
    fileprivate static func namespace(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNamespace
        )
    }
}
