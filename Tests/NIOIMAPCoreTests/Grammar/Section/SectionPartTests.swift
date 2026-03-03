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

@Suite("SectionPart")
struct SectionPartTests {
    @Test(arguments: [
        EncodeFixture.sectionPart([], ""),
        EncodeFixture.sectionPart([715_472], "715472"),
        EncodeFixture.sectionPart([1, 2, 3, 5, 8, 11], "1.2.3.5.8.11"),
    ])
    func encode(_ fixture: EncodeFixture<SectionSpecifier.Part>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.sectionPart("1", expected: .success([1])),
        ParseFixture.sectionPart("1.2", expected: .success([1, 2])),
        ParseFixture.sectionPart("1.2.3.4.5", expected: .success([1, 2, 3, 4, 5])),
        ParseFixture.sectionPart("", expected: .failure),
        ParseFixture.sectionPart("1.", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<SectionSpecifier.Part>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SectionSpecifier.Part> {
    fileprivate static func sectionPart(
        _ input: SectionSpecifier.Part,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSectionPart($1) }
        )
    }
}

extension ParseFixture<SectionSpecifier.Part> {
    fileprivate static func sectionPart(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSectionPart
        )
    }
}
