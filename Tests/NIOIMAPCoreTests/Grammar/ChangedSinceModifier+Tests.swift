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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ChangedSinceModifier")
struct ChangedSinceModifierTests {
    @Test(
        "encode changed since",
        arguments: [
            EncodeFixture.changedSinceModifier(.init(modificationSequence: 3), "CHANGEDSINCE 3"),
            EncodeFixture.changedSinceModifier(.init(modificationSequence: 999999), "CHANGEDSINCE 999999"),
        ]
    )
    func encodeChangedSince(_ fixture: EncodeFixture<ChangedSinceModifier>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode unchanged since",
        arguments: [
            EncodeFixture.unchangedSinceModifier(.init(modificationSequence: 3), "UNCHANGEDSINCE 3"),
            EncodeFixture.unchangedSinceModifier(.init(modificationSequence: 12345), "UNCHANGEDSINCE 12345"),
        ]
    )
    func encodeUnchangedSince(_ fixture: EncodeFixture<UnchangedSinceModifier>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse changed since modifier",
        arguments: [
            ParseFixture.changedSinceModifier(
                "CHANGEDSINCE 1",
                " ",
                expected: .success(.init(modificationSequence: 1))
            ),
            ParseFixture.changedSinceModifier(
                "changedsince 1",
                " ",
                expected: .success(.init(modificationSequence: 1))
            ),
            ParseFixture.changedSinceModifier("TEST", "", expected: .failure),
            ParseFixture.changedSinceModifier("CHANGEDSINCE a", "", expected: .failure),
            ParseFixture.changedSinceModifier("CHANGEDSINCE 1", "", expected: .incompleteMessage),
        ]
    )
    func parseChangedSinceModifier(_ fixture: ParseFixture<ChangedSinceModifier>) {
        fixture.checkParsing()
    }

    @Test(
        "parse unchanged since modifier",
        arguments: [
            ParseFixture.unchangedSinceModifier(
                "UNCHANGEDSINCE 1",
                " ",
                expected: .success(.init(modificationSequence: 1))
            ),
            ParseFixture.unchangedSinceModifier(
                "unchangedsince 1",
                " ",
                expected: .success(.init(modificationSequence: 1))
            ),
            ParseFixture.unchangedSinceModifier("TEST", "", expected: .failure),
            ParseFixture.unchangedSinceModifier("UNCHANGEDSINCE a", "", expected: .failure),
            ParseFixture.unchangedSinceModifier("UNCHANGEDSINCE 1", "", expected: .incompleteMessage),
        ]
    )
    func parseUnchangedSinceModifier(_ fixture: ParseFixture<UnchangedSinceModifier>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ChangedSinceModifier> {
    fileprivate static func changedSinceModifier(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeChangedSinceModifier($1) }
        )
    }
}

extension EncodeFixture<UnchangedSinceModifier> {
    fileprivate static func unchangedSinceModifier(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUnchangedSinceModifier($1) }
        )
    }
}

extension ParseFixture<ChangedSinceModifier> {
    fileprivate static func changedSinceModifier(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseChangedSinceModifier
        )
    }
}

extension ParseFixture<UnchangedSinceModifier> {
    fileprivate static func unchangedSinceModifier(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUnchangedSinceModifier
        )
    }
}
