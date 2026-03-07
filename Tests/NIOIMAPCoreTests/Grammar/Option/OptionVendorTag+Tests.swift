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

@Suite("KeyValue<String, String>")
struct OptionVendorTagTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.optionVendorTag(.init(key: "some", value: "thing"), "some-thing")
        ]
    )
    func encode(_ fixture: EncodeFixture<KeyValue<String, String>>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.optionVendorTag("ACME-SORT", ")", expected: .success(.init(key: "ACME", value: "SORT"))),
            ParseFixture.optionVendorTag("FOO-BAR", ")", expected: .success(.init(key: "FOO", value: "BAR"))),
            ParseFixture.optionVendorTag("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<KeyValue<String, String>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<String, String>> {
    fileprivate static func optionVendorTag(
        _ input: KeyValue<String, String>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionVendorTag($1) }
        )
    }
}

extension ParseFixture<KeyValue<String, String>> {
    fileprivate static func optionVendorTag(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionVendorTag
        )
    }
}
