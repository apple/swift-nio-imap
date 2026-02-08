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

@Suite("AppendOptions")
struct AppendOptionsTests {
    @Test(arguments: [
        EncodeFixture.appendOptions(
            .none,
            ""
        ),
        EncodeFixture.appendOptions(
            .init(flagList: [.answered], internalDate: nil, extensions: [:]),
            " (\\Answered)"
        ),
        EncodeFixture.appendOptions(
            .init(
                flagList: [.answered],
                internalDate: ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1994,
                        month: 6,
                        day: 25,
                        hour: 1,
                        minute: 2,
                        second: 3,
                        timeZoneMinutes: 0
                    )!
                ),
                extensions: [:]
            ),
            " (\\Answered) \"25-Jun-1994 01:02:03 +0000\""
        ),
    ])
    func encode(_ fixture: EncodeFixture<AppendOptions>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.appendOptions("", expected: .success(.none)),
        ParseFixture.appendOptions(" (\\Answered)", expected: .success(.init(flagList: [.answered], internalDate: nil, extensions: [:]))),
        ParseFixture.appendOptions(
            " \"25-jun-1994 01:02:03 +0000\"",
            expected: .success(.init(
                flagList: [],
                internalDate: ServerMessageDate(ServerMessageDate.Components(
                    year: 1994,
                    month: 6,
                    day: 25,
                    hour: 1,
                    minute: 2,
                    second: 3,
                    timeZoneMinutes: 0
                )!),
                extensions: [:]
            ))
        ),
        ParseFixture.appendOptions(
            " name1 1:2",
            expected: .success(.init(flagList: [], internalDate: nil, extensions: ["name1": .sequence(.range(1...2))]))
        ),
        ParseFixture.appendOptions(
            " name1 1:2 name2 2:3 name3 3:4",
            expected: .success(.init(
                flagList: [],
                internalDate: nil,
                extensions: [
                    "name1": .sequence(.range(1...2)),
                    "name2": .sequence(.range(2...3)),
                    "name3": .sequence(.range(3...4)),
                ]
            ))
        ),
    ])
    func parse(_ fixture: ParseFixture<AppendOptions>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AppendOptions> {
    fileprivate static func appendOptions(
        _ input: AppendOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .client(.rfc3501),
            expectedString: expectedString,
            encoder: { $0.writeAppendOptions($1) }
        )
    }
}

extension ParseFixture<AppendOptions> {
    fileprivate static func appendOptions(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAppendOptions
        )
    }
}
