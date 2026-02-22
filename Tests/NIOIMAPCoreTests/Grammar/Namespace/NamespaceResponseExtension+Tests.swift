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

@Suite("NamespaceResponse Extensions")
struct NamespaceResponseExtensionTests {
    @Test(arguments: [
        EncodeFixture.namespaceResponseExtensions([:], ""),
        EncodeFixture.namespaceResponseExtensions(
            ["str1": ["str2"]],
            " \"str1\" (\"str2\")"
        ),
        EncodeFixture.namespaceResponseExtensions(
            [
                "str1": ["str2"],
                "str3": ["str4"],
                "str5": ["str6"]
            ],
            " \"str1\" (\"str2\") \"str3\" (\"str4\") \"str5\" (\"str6\")"
        )
    ])
    func encode(_ fixture: EncodeFixture<OrderedDictionary<ByteBuffer, [ByteBuffer]>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.namespaceResponseExtension(
            " \"str1\" (\"str2\")",
            " ",
            expected: .success(KeyValue(key: "str1", value: ["str2"]))
        ),
        ParseFixture.namespaceResponseExtension(
            " \"str1\" (\"str2\" \"str3\" \"str4\")",
            " ",
            expected: .success(KeyValue(key: "str1", value: ["str2", "str3", "str4"]))
        )
    ])
    func parse(_ fixture: ParseFixture<KeyValue<ByteBuffer, [ByteBuffer]>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<OrderedDictionary<ByteBuffer, [ByteBuffer]>> {
    fileprivate static func namespaceResponseExtensions(
        _ input: OrderedDictionary<ByteBuffer, [ByteBuffer]>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNamespaceResponseExtensions($1) }
        )
    }
}

extension ParseFixture<KeyValue<ByteBuffer, [ByteBuffer]>> {
    fileprivate static func namespaceResponseExtension(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNamespaceResponseExtension
        )
    }
}
