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

@Suite("EncodedSection")
struct EncodedSectionTests {
    @Test(arguments: [
        EncodeFixture.encodedSection(.init(section: "hello"), "hello"),
    ])
    func encode(_ fixture: EncodeFixture<EncodedSection>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedSection(
            "query%FF",
            " ",
            expected: .success(.init(section: "query%FF"))
        ),
    ])
    func parse(_ fixture: ParseFixture<EncodedSection>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EncodedSection> {
    fileprivate static func encodedSection(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedSection($1) }
        )
    }
}

extension ParseFixture<EncodedSection> {
    fileprivate static func encodedSection(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedSection
        )
    }
}
