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

@Suite("CreateParameter")
struct CreateParameterTests {
    @Test(arguments: [
        EncodeFixture.createParameter(
            .labelled(.init(key: "name", value: nil)),
            "name"
        ),
        EncodeFixture.createParameter(
            .labelled(.init(key: "name", value: .sequence(.set([1])))),
            "name 1"
        ),
        EncodeFixture.createParameter(
            .attributes([]),
            "USE ()"
        ),
        EncodeFixture.createParameter(
            .attributes([.all]),
            "USE (\\All)"
        ),
        EncodeFixture.createParameter(
            .attributes([.all, .flagged]),
            "USE (\\All \\Flagged)"
        )
    ])
    func encode(_ fixture: EncodeFixture<CreateParameter>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse single create parameter",
        arguments: [
            ParseFixture.createParameter(
                "param",
                expected: .success(.labelled(.init(key: "param", value: nil)))
            ),
            ParseFixture.createParameter(
                "param 1",
                expected: .success(.labelled(.init(key: "param", value: .sequence(.set([1])))))
            ),
            ParseFixture.createParameter(
                "USE (\\All)",
                expected: .success(.attributes([.all]))
            ),
            ParseFixture.createParameter(
                "USE (\\All \\Sent \\Drafts)",
                expected: .success(.attributes([.all, .sent, .drafts]))
            ),
            ParseFixture.createParameter("param", "", expected: .incompleteMessage),
            ParseFixture.createParameter("param 1", "", expected: .incompleteMessage),
            ParseFixture.createParameter("USE (\\Test", "", expected: .incompleteMessage),
            ParseFixture.createParameter("USE (\\All ", "", expected: .incompleteMessage)
        ]
    )
    func parseSingleCreateParameter(_ fixture: ParseFixture<CreateParameter>) {
        fixture.checkParsing()
    }

    @Test(
        "parse create parameters list",
        arguments: [
            ParseFixture.createParameters(
                " (param1 param2)",
                expected: .success([
                    .labelled(.init(key: "param1", value: nil)),
                    .labelled(.init(key: "param2", value: nil))
                ])
            ),
            ParseFixture.createParameters(" (param1", expected: .failure),
            ParseFixture.createParameters(" (param1", "", expected: .incompleteMessage)
        ]
    )
    func parseCreateParametersList(_ fixture: ParseFixture<[CreateParameter]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<CreateParameter> {
    fileprivate static func createParameter(
        _ input: CreateParameter,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCreateParameter($1) }
        )
    }
}

extension ParseFixture<CreateParameter> {
    fileprivate static func createParameter(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCreateParameter
        )
    }
}

extension ParseFixture<[CreateParameter]> {
    fileprivate static func createParameters(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCreateParameters
        )
    }
}
