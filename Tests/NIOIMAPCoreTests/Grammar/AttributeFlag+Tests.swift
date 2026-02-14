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

@Suite("AttributeFlag")
struct AttributeFlagTests {
    @Test(arguments: [
        EncodeFixture.attributeFlag(.answered, "\\\\answered"),
        EncodeFixture.attributeFlag(.deleted, "\\\\deleted"),
        EncodeFixture.attributeFlag(.draft, "\\\\draft"),
        EncodeFixture.attributeFlag(.flagged, "\\\\flagged"),
        EncodeFixture.attributeFlag(.seen, "\\\\seen"),
        EncodeFixture.attributeFlag(.init("test"), "test"),
    ])
    func encode(_ fixture: EncodeFixture<AttributeFlag>) {
        fixture.checkEncoding()
    }

    @Test func `lowercased normalization`() {
        #expect(AttributeFlag("TEST") == AttributeFlag("test"))
        #expect(AttributeFlag("TEST").stringValue == "test")
        #expect(AttributeFlag("test").stringValue == "test")
    }

    @Test(arguments: [
        ParseFixture.attributeFlag(#"\\Answered"#, expected: .success(.answered)),
        ParseFixture.attributeFlag("some", expected: .success(.init("some"))),
    ])
    func parse(_ fixture: ParseFixture<AttributeFlag>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AttributeFlag> {
    fileprivate static func attributeFlag(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAttributeFlag($1) }
        )
    }
}

extension ParseFixture<AttributeFlag> {
    fileprivate static func attributeFlag(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAttributeFlag
        )
    }
}
