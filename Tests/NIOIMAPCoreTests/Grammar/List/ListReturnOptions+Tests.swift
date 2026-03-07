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

@Suite("ListReturnOptions")
struct ListReturnOptionsTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.listReturnOptions([], "RETURN ()"),
            EncodeFixture.listReturnOptions([.subscribed], "RETURN (SUBSCRIBED)"),
            EncodeFixture.listReturnOptions([.subscribed, .children], "RETURN (SUBSCRIBED CHILDREN)"),
        ]
    )
    func encode(_ fixture: EncodeFixture<[ReturnOption]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.returnOption("SUBSCRIBED", ")", expected: .success(.subscribed)),
        ParseFixture.returnOption("CHILDREN", ")", expected: .success(.children)),
        ParseFixture.returnOption("STATUS (MESSAGES)", " ", expected: .success(.statusOption([.messageCount]))),
        ParseFixture.returnOption(
            "MYEXT",
            ")",
            expected: .success(.optionExtension(.init(key: .standard("MYEXT"), value: nil)))
        ),
        ParseFixture.returnOption("", "", expected: .incompleteMessage),
        ParseFixture.returnOption("123invalid", expected: .failure),
    ])
    func parse(_ fixture: ParseFixture<ReturnOption>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[ReturnOption]> {
    fileprivate static func listReturnOptions(
        _ input: [ReturnOption],
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListReturnOptions($1) }
        )
    }
}

extension ParseFixture<ReturnOption> {
    fileprivate static func returnOption(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseReturnOption
        )
    }
}
