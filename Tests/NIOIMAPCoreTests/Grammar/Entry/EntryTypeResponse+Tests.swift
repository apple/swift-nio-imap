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

@Suite("Entry Type Response")
struct EntryTypeResponseTests {
    @Test(arguments: [
        EncodeFixture.entryKindResponse(.private, "priv"),
        EncodeFixture.entryKindResponse(.shared, "shared")
    ])
    func encode(_ fixture: EncodeFixture<EntryKindResponse>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.entryKindResponse("priv", expected: .success(.private)),
        ParseFixture.entryKindResponse("PRIV", expected: .success(.private)),
        ParseFixture.entryKindResponse("prIV", expected: .success(.private)),
        ParseFixture.entryKindResponse("shared", expected: .success(.shared)),
        ParseFixture.entryKindResponse("SHARED", expected: .success(.shared)),
        ParseFixture.entryKindResponse("shaRED", expected: .success(.shared))
    ])
    func parse(_ fixture: ParseFixture<EntryKindResponse>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EntryKindResponse> {
    fileprivate static func entryKindResponse(
        _ input: EntryKindResponse,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntryKindResponse($1) }
        )
    }
}

extension ParseFixture<EntryKindResponse> {
    fileprivate static func entryKindResponse(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntryKindResponse
        )
    }
}
