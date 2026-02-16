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

@Suite("MetadataValue")
struct MetadataValueTests {
    @Test(arguments: [
        EncodeFixture.metadataValue(
            .init(nil),
            .rfc3501,
            ["NIL"]
        ),
        EncodeFixture.metadataValue(
            .init("test"),
            .rfc3501,
            ["~{4}\r\n", "test"]
        ),
        EncodeFixture.metadataValue(
            .init("\\"),
            .rfc3501,
            ["~{1}\r\n", "\\"]
        ),
        EncodeFixture.metadataValue(
            .init("\0"),
            .init(capabilities: [.binary]),
            ["~{1}\r\n", "\0"]
        ),
    ])
    func encode(_ fixture: EncodeFixture<MetadataValue>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.metadataValue("NIL", expected: .success(.init(nil))),
        ParseFixture.metadataValue("\"a\"", expected: .success(.init("a"))),
        ParseFixture.metadataValue("{1}\r\na", expected: .success(.init("a"))),
        ParseFixture.metadataValue("~{1}\r\na", expected: .success(.init("a"))),
    ])
    func parse(_ fixture: ParseFixture<MetadataValue>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MetadataValue> {
    fileprivate static func metadataValue(
        _ input: MetadataValue,
        _ options: CommandEncodingOptions,
        _ expectedStrings: [String]
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(options),
            expectedStrings: expectedStrings,
            encoder: { $0.writeMetadataValue($1) }
        )
    }
}

extension ParseFixture<MetadataValue> {
    fileprivate static func metadataValue(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMetadataValue
        )
    }
}
