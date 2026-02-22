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

@Suite("SequenceMatchData")
struct SequenceMatchDataTests {
    @Test(arguments: [
        EncodeFixture.sequenceMatchData(.init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)), "(1:* 1:*)"),
        EncodeFixture.sequenceMatchData(
            .init(knownSequenceSet: .set([1, 2, 3]), knownUidSet: .set([4, 5, 6])),
            "(1:3 4:6)"
        )
    ])
    func encode(_ fixture: EncodeFixture<SequenceMatchData>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.sequenceMatchData(
            "(1:* 1:*)",
            expected: .success(.init(knownSequenceSet: .set(.all), knownUidSet: .set(.all)))
        ),
        ParseFixture.sequenceMatchData(
            "(1,2 3,4)",
            expected: .success(.init(knownSequenceSet: .set([1, 2]), knownUidSet: .set([3, 4])))
        ),
        ParseFixture.sequenceMatchData("()", "", expected: .failure),
        ParseFixture.sequenceMatchData("(* )", "", expected: .failure),
        ParseFixture.sequenceMatchData("(1", "", expected: .incompleteMessage),
        ParseFixture.sequenceMatchData("(1111:2222", "", expected: .incompleteMessage)
    ])
    func parse(_ fixture: ParseFixture<SequenceMatchData>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SequenceMatchData> {
    fileprivate static func sequenceMatchData(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSequenceMatchData($1) }
        )
    }
}

extension ParseFixture<SequenceMatchData> {
    fileprivate static func sequenceMatchData(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSequenceMatchData
        )
    }
}
