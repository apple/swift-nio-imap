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

@Suite("ParameterValue")
struct ParameterValueTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.parameterValue(.sequence(.set(.init(range: .init(SequenceNumber(1))))), "1"),
            EncodeFixture.parameterValue(.sequence(.lastCommand), "$"),
            EncodeFixture.parameterValue(.comp(["foo", "bar"]), #"(("foo" "bar"))"#),
            EncodeFixture.parameterValue(.comp([]), "()"),
        ]
    )
    func encode(_ fixture: EncodeFixture<ParameterValue>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.parameterValue(
                "1",
                expected: .success(.sequence(.set(.init(range: .init(SequenceNumber(1))))))
            ),
            ParseFixture.parameterValue("$", expected: .success(.sequence(.lastCommand))),
            ParseFixture.parameterValue(#"(("foo" "bar"))"#, ")", expected: .success(.comp(["foo", "bar"]))),
            ParseFixture.parameterValue("()", ")", expected: .success(.comp([]))),
            ParseFixture.parameterValue("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<ParameterValue>) {
        fixture.checkParsing()
    }

    @Test(
        "parse parameter",
        arguments: [
            ParseFixture.parameter("USE", ")", expected: .success(.init(key: "USE", value: nil))),
            ParseFixture.parameter(
                "USE 1",
                ")",
                expected: .success(.init(key: "USE", value: .sequence(.set(.init(range: .init(SequenceNumber(1)))))))
            ),
            ParseFixture.parameter("USE $", ")", expected: .success(.init(key: "USE", value: .sequence(.lastCommand)))),
            ParseFixture.parameter("", "", expected: .incompleteMessage),
        ]
    )
    func parseParameter(_ fixture: ParseFixture<KeyValue<String, ParameterValue?>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ParameterValue> {
    fileprivate static func parameterValue(_ input: ParameterValue, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeParameterValue($1) }
        )
    }
}

extension ParseFixture<ParameterValue> {
    fileprivate static func parameterValue(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseParameterValue
        )
    }
}

extension ParseFixture<KeyValue<String, ParameterValue?>> {
    fileprivate static func parameter(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseParameter
        )
    }
}
