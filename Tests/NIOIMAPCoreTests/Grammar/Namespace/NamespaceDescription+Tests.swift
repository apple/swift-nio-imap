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

@Suite("NamespaceDescription")
struct NamespaceDescriptionTests {
    @Test(arguments: [
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: nil, responseExtensions: [:]),
            "(\"string\" NIL)"
        ),
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: "a", responseExtensions: [:]),
            "(\"string\" \"a\")"
        ),
        EncodeFixture.namespaceDescription(
            .init(string: "string", char: nil, responseExtensions: ["str2": ["str3"]]),
            "(\"string\" NIL \"str2\" (\"str3\"))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NamespaceDescription>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.namespaceDescription(
            "(\"str1\" NIL)",
            " ",
            expected: .success(.init(string: "str1", char: nil, responseExtensions: [:]))
        ),
        ParseFixture.namespaceDescription(
            "(\"str\" \"a\")",
            " ",
            expected: .success(.init(string: "str", char: "a", responseExtensions: [:]))
        ),
    ])
    func parse(_ fixture: ParseFixture<NamespaceDescription>) {
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
