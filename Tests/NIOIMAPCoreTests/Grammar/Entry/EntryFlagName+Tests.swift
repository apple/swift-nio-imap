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

@Suite("EntryFlagName")
struct EntryFlagNameTests {
    @Test(arguments: [
        EncodeFixture.entryFlagName(.init(flag: .answered), "\"/flags/\\\\answered\""),
        EncodeFixture.entryFlagName(.init(flag: .deleted), "\"/flags/\\\\deleted\""),
        EncodeFixture.entryFlagName(.init(flag: .init("\\\\CustomFlag")), "\"/flags/\\\\customflag\""),
    ])
    func encoding(_ fixture: EncodeFixture<EntryFlagName>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.entryFlagName(
            "\"/flags/\\\\Answered\"",
            "",
            expected: .success(.init(flag: .answered))
        ),
        ParseFixture.entryFlagName(
            "/flags/\\Answered",
            "",
            expected: .failure
        ),
        ParseFixture.entryFlagName(
            "\"/flags",
            "",
            expected: .incompleteMessage
        ),
    ])
    func parse(_ fixture: ParseFixture<EntryFlagName>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EntryFlagName> {
    fileprivate static func entryFlagName(_ input: EntryFlagName, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEntryFlagName($1) }
        )
    }
}

extension ParseFixture<EntryFlagName> {
    fileprivate static func entryFlagName(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEntryFlagName
        )
    }
}
