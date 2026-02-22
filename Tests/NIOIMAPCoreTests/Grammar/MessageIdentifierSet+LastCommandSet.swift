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

@Suite("LastCommandSet")
struct LastCommandSetTests {
    @Test(arguments: [
        ParseFixture.lastCommandSet("765", " ", expected: .success(.set([765]))),
        ParseFixture.lastCommandSet(
            "1,2:5,7,9:*",
            " ",
            expected: .success(
                .set([
                    MessageIdentifierRange<SequenceNumber>(1), MessageIdentifierRange<SequenceNumber>(2...5),
                    MessageIdentifierRange<SequenceNumber>(7), MessageIdentifierRange<SequenceNumber>(9...)
                ])
            )
        ),
        ParseFixture.lastCommandSet("1:*", expected: .success(.set([.all]))),
        ParseFixture.lastCommandSet("1:2", expected: .success(.set([1...2]))),
        ParseFixture.lastCommandSet("1:2,2:3,3:4", expected: .success(.set([1...2, 2...3, 3...4]))),
        ParseFixture.lastCommandSet("$", expected: .success(.lastCommand)),
        ParseFixture.lastCommandSet("a", " ", expected: .failure),
        ParseFixture.lastCommandSet(":", "", expected: .failure),
        ParseFixture.lastCommandSet(":2", "", expected: .failure),
        ParseFixture.lastCommandSet("", "", expected: .incompleteMessage),
        ParseFixture.lastCommandSet("1,", "", expected: .incompleteMessage),
        ParseFixture.lastCommandSet("1111", "", expected: .incompleteMessage),
        ParseFixture.lastCommandSet("1111:2222", "", expected: .incompleteMessage)
    ])
    func parse(_ fixture: ParseFixture<LastCommandSet<SequenceNumber>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<LastCommandSet<SequenceNumber>> {
    fileprivate static func lastCommandSet(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMessageIdentifierSetOrLast
        )
    }
}
