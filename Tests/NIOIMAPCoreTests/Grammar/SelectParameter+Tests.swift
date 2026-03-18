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

@Suite("SelectParameter")
struct SelectParameterTests {
    @Test(arguments: [
        EncodeFixture.selectParameter(
            .condStore,
            "CONDSTORE"
        ),
        EncodeFixture.selectParameter(
            .basic(.init(key: "test", value: nil)),
            "test"
        ),
        EncodeFixture.selectParameter(
            .basic(.init(key: "test", value: .sequence(.set([1])))),
            "test 1"
        ),
        EncodeFixture.selectParameter(
            .qresync(
                .init(uidValidity: 1, modificationSequenceValue: .zero, knownUIDs: nil, sequenceMatchData: nil)
            ),
            "QRESYNC (1 0)"
        ),
        EncodeFixture.selectParameter(
            .qresync(
                .init(uidValidity: 1, modificationSequenceValue: .zero, knownUIDs: [1], sequenceMatchData: nil)
            ),
            "QRESYNC (1 0 1)"
        ),
        EncodeFixture.selectParameter(
            .qresync(
                .init(
                    uidValidity: 1,
                    modificationSequenceValue: .zero,
                    knownUIDs: nil,
                    sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all))
                )
            ),
            "QRESYNC (1 0 (1:* 1:*))"
        ),
        EncodeFixture.selectParameter(
            .qresync(
                .init(
                    uidValidity: 1,
                    modificationSequenceValue: .zero,
                    knownUIDs: [1],
                    sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all))
                )
            ),
            "QRESYNC (1 0 1 (1:* 1:*))"
        ),
        EncodeFixture.selectParameter(
            .qresync(
                .init(
                    uidValidity: 999,
                    modificationSequenceValue: .init(50),
                    knownUIDs: [2, 5, 10],
                    sequenceMatchData: .init(knownSequenceSet: .set([1...10]), knownUidSet: .set([5...20]))
                )
            ),
            "QRESYNC (999 50 2,5,10 (1:10 5:20))"
        ),
    ])
    func encode(_ fixture: EncodeFixture<SelectParameter>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.selectParameter(
            "test 1",
            expected: .success(.basic(.init(key: "test", value: .sequence(.set([1])))))
        ),
        ParseFixture.selectParameter(
            "CONDSTORE",
            expected: .success(.condStore)
        ),
        ParseFixture.selectParameter(
            "QRESYNC (1 1)",
            expected: .success(
                .qresync(.init(uidValidity: 1, modificationSequenceValue: 1, knownUIDs: nil, sequenceMatchData: nil))
            )
        ),
        ParseFixture.selectParameter(
            "QRESYNC (1 1 1:2)",
            expected: .success(
                .qresync(
                    .init(uidValidity: 1, modificationSequenceValue: 1, knownUIDs: [1...2], sequenceMatchData: nil)
                )
            )
        ),
        ParseFixture.selectParameter(
            "QRESYNC (1 1 1:2 (1:* 1:*))",
            expected: .success(
                .qresync(
                    .init(
                        uidValidity: 1,
                        modificationSequenceValue: 1,
                        knownUIDs: [1...2],
                        sequenceMatchData: .init(knownSequenceSet: .set(.all), knownUidSet: .set(.all))
                    )
                )
            )
        ),
        ParseFixture.selectParameter("1", expected: .failure),
        ParseFixture.selectParameter("test ", "", expected: .incompleteMessage),
        ParseFixture.selectParameter("QRESYNC (", "", expected: .incompleteMessage),
        ParseFixture.selectParameter("QRESYNC (1 1", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<SelectParameter>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SelectParameter> {
    fileprivate static func selectParameter(
        _ input: SelectParameter,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSelectParameter($1) }
        )
    }
}

extension ParseFixture<SelectParameter> {
    fileprivate static func selectParameter(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSelectParameter
        )
    }
}
