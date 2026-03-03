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

@Suite("MetadataResponse")
struct MetadataResponseTests {
    @Test(arguments: [
        EncodeFixture.metadataResponse(
            .list(list: ["a"], mailbox: .inbox),
            "METADATA \"INBOX\" \"a\""
        ),
        EncodeFixture.metadataResponse(
            .list(list: ["a", "b", "c"], mailbox: .inbox),
            "METADATA \"INBOX\" \"a\" \"b\" \"c\""
        ),
        EncodeFixture.metadataResponse(
            .values(values: ["a": .init(nil)], mailbox: .inbox),
            "METADATA \"INBOX\" (\"a\" NIL)"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MetadataResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.metadataResponse("METADATA INBOX \"a\"", expected: .success(.list(list: ["a"], mailbox: .inbox))),
        ParseFixture.metadataResponse(
            "METADATA INBOX \"a\" \"b\" \"c\"",
            expected: .success(.list(list: ["a", "b", "c"], mailbox: .inbox))
        ),
        ParseFixture.metadataResponse(
            "METADATA INBOX (\"a\" NIL)",
            expected: .success(.values(values: ["a": .init(nil)], mailbox: .inbox))
        ),
    ])
    func parse(_ fixture: ParseFixture<MetadataResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MetadataResponse> {
    fileprivate static func metadataResponse(
        _ input: MetadataResponse,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMetadataResponse($1) }
        )
    }
}

extension ParseFixture<MetadataResponse> {
    fileprivate static func metadataResponse(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMetadataResponse
        )
    }
}
