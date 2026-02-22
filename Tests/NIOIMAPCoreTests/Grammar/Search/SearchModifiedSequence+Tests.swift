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

@Suite("SearchModificationSequence")
struct SearchModifiedSequenceTests {
    @Test(arguments: [
        EncodeFixture.searchModificationSequence(.init(extensions: [:], sequenceValue: 1), "MODSEQ 1"),
        EncodeFixture.searchModificationSequence(
            .init(extensions: [.init(flag: .answered): .all], sequenceValue: .init(integerLiteral: 1)),
            "MODSEQ \"/flags/\\\\answered\" all 1"
        ),
        EncodeFixture.searchModificationSequence(
            .init(
                extensions: [.init(flag: .answered): .all, .init(flag: .seen): .private],
                sequenceValue: .init(integerLiteral: 1)
            ),
            "MODSEQ \"/flags/\\\\answered\" all \"/flags/\\\\seen\" priv 1"
        ),
        EncodeFixture.searchModificationSequence(.init(extensions: [:], sequenceValue: 1), "MODSEQ 1")
    ])
    func encode(_ fixture: EncodeFixture<SearchModificationSequence>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchModificationSequence(
            "MODSEQ 4",
            expected: .success(.init(extensions: [:], sequenceValue: 4))
        ),
        ParseFixture.searchModificationSequence(
            #"MODSEQ "/flags/\\Answered" priv 4"#,
            expected: .success(.init(extensions: [.init(flag: .answered): .private], sequenceValue: 4))
        ),
        ParseFixture.searchModificationSequence(
            #"MODSEQ "/flags/\\Answered" priv "/flags/\\Seen" shared 4"#,
            expected: .success(
                .init(
                    extensions: [
                        .init(flag: .answered): .private,
                        .init(flag: .seen): .shared
                    ],
                    sequenceValue: 4
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<SearchModificationSequence>) {
        fixture.checkParsing()
    }

    @Test(
        "parse extension",
        arguments: [
            ParseFixture.searchModificationSequenceExtension(
                #" "/flags/\\Seen" all"#,
                "",
                expected: .success(.init(key: .init(flag: .seen), value: .all))
            )
        ]
    )
    func parseExtension(_ fixture: ParseFixture<KeyValue<EntryFlagName, EntryKindRequest>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SearchModificationSequence> {
    fileprivate static func searchModificationSequence(
        _ input: SearchModificationSequence,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchModificationSequence($1) }
        )
    }
}

extension ParseFixture<SearchModificationSequence> {
    fileprivate static func searchModificationSequence(
        _ input: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: " ",
            expected: expected,
            parser: GrammarParser().parseSearchModificationSequence
        )
    }
}

extension ParseFixture<KeyValue<EntryFlagName, EntryKindRequest>> {
    fileprivate static func searchModificationSequenceExtension(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchModificationSequenceExtension
        )
    }
}
