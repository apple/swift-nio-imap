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
@testable import NIOIMAPCore
import XCTest

class GrammarParser_Envelope_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseEnvelopeEmailAddressGroups

extension GrammarParser_Envelope_Tests {
    func testParseEnvelopeEmailAddressGroups() {
        let inputs: [([EmailAddress], [EmailAddressListElement], UInt)] = [
            ([], [], #line),  // extreme case, this should never happen, but we don't want to crash
            (  // single address
                [.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")],
                [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))],
                #line
            ),
            (  // multiple addresses
                [
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                ],
                [
                    .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                    .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                ],
                #line
            ),
            (  // single group: 1 address
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(
                        .init(
                            groupName: "group",
                            sourceRoot: nil,
                            children: [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))]
                        )
                    )
                ],
                #line
            ),
            (  // 1 address with no information
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)
                ],
                [
                    .singleAddress(.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil))
                ],
                #line
            ),
            (  // single group: 1 address
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                    .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(
                        .init(
                            groupName: "group",
                            sourceRoot: nil,
                            children: [
                                .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                                .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                                .singleAddress(.init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c")),
                            ]
                        )
                    )
                ],
                #line
            ),
            (  // nested groups
                [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group1", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: nil, sourceRoot: nil, mailbox: "group2", host: nil),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                    .init(personName: nil, sourceRoot: nil, mailbox: "group3", host: nil),
                    .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                [
                    .group(
                        .init(
                            groupName: "group1",
                            sourceRoot: nil,
                            children: [
                                .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                                .group(
                                    .init(
                                        groupName: "group2",
                                        sourceRoot: nil,
                                        children: [
                                            .singleAddress(
                                                .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")
                                            ),
                                            .group(
                                                .init(
                                                    groupName: "group3",
                                                    sourceRoot: nil,
                                                    children: [
                                                        .singleAddress(
                                                            .init(
                                                                personName: "c",
                                                                sourceRoot: "c",
                                                                mailbox: "c",
                                                                host: "c"
                                                            )
                                                        )
                                                    ]
                                                )
                                            ),
                                        ]
                                    )
                                ),
                            ]
                        )
                    )
                ],
                #line
            ),
        ]
        for (original, expected, line) in inputs {
            let actual = GrammarParser().parseEnvelopeEmailAddressGroups(original)
            XCTAssertEqual(actual, expected, line: line)
        }
    }
}
