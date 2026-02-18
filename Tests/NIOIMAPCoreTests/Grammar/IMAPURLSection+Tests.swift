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

@Suite("URLMessageSection")
struct URLMessageSectionTests {
    @Test("encode URL message section", arguments: [
        EncodeFixture.urlMessageSection(.init(encodedSection: .init(section: "test")), "/;SECTION=test")
    ])
    func encodeURLMessageSection(_ fixture: EncodeFixture<URLMessageSection>) {
        fixture.checkEncoding()
    }

    @Test("encode URL message section only", arguments: [
        EncodeFixture.urlMessageSectionOnly(.init(encodedSection: .init(section: "test")), ";SECTION=test")
    ])
    func encodeURLMessageSectionOnly(_ fixture: EncodeFixture<URLMessageSection>) {
        fixture.checkEncoding()
    }

    @Test("parse with slash", arguments: [
        ParseFixture.urlMessageSectionWithSlash(
            "/;SECTION=a",
            " ",
            expected: .success(.init(encodedSection: .init(section: "a")))
        ),
        ParseFixture.urlMessageSectionWithSlash(
            "/;SECTION=abc",
            " ",
            expected: .success(.init(encodedSection: .init(section: "abc")))
        ),
        ParseFixture.urlMessageSectionWithSlash(
            "SECTION=a",
            " ",
            expected: .failure
        ),
        ParseFixture.urlMessageSectionWithSlash(
            "/;SECTION=1",
            "",
            expected: .incompleteMessage
        ),
    ])
    func parseWithSlash(_ fixture: ParseFixture<URLMessageSection>) {
        fixture.checkParsing()
    }

    @Test("parse without slash", arguments: [
        ParseFixture.urlMessageSectionWithoutSlash(
            ";SECTION=a",
            " ",
            expected: .success(.init(encodedSection: .init(section: "a")))
        ),
        ParseFixture.urlMessageSectionWithoutSlash(
            ";SECTION=abc",
            " ",
            expected: .success(.init(encodedSection: .init(section: "abc")))
        ),
        ParseFixture.urlMessageSectionWithoutSlash(
            "SECTION=a",
            " ",
            expected: .failure
        ),
        ParseFixture.urlMessageSectionWithoutSlash(
            ";SECTION=1",
            "",
            expected: .incompleteMessage
        ),
    ])
    func parseWithoutSlash(_ fixture: ParseFixture<URLMessageSection>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<URLMessageSection> {
    fileprivate static func urlMessageSection(
        _ input: URLMessageSection,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLMessageSection($1) }
        )
    }

    fileprivate static func urlMessageSectionOnly(
        _ input: URLMessageSection,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLMessageSectionOnly($1) }
        )
    }
}

extension ParseFixture<URLMessageSection> {
    fileprivate static func urlMessageSectionWithSlash(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIMAPURLSection
        )
    }

    fileprivate static func urlMessageSectionWithoutSlash(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIMAPURLSectionOnly
        )
    }
}
