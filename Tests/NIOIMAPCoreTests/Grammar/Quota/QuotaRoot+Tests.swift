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

@Suite("QuotaRoot")
struct QuotaRootTests {
    @Test(arguments: [
        EncodeFixture.quotaRoot(QuotaRoot(""), #""""#),
        EncodeFixture.quotaRoot(QuotaRoot("MassivePool"), #""MassivePool""#),
    ])
    func encode(_ fixture: EncodeFixture<QuotaRoot>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.quotaRoot(#""MassivePool""#, expected: .success(QuotaRoot("MassivePool"))),
        ParseFixture.quotaRoot("inbox", expected: .success(QuotaRoot("inbox"))),
        ParseFixture.quotaRoot(#""""#, expected: .success(QuotaRoot(""))),
        ParseFixture.quotaRoot("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<QuotaRoot>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        (QuotaRoot("MassivePool"), "MassivePool" as String?),
        (QuotaRoot(""), "" as String?),
        (QuotaRoot(ByteBuffer(bytes: [0xFF, 0xFE])), nil as String?),
    ] as [(QuotaRoot, String?)])
    func stringConversion(_ fixture: (QuotaRoot, String?)) {
        #expect(String(fixture.0) == fixture.1)
    }

    @Test(arguments: [
        (QuotaRoot("MassivePool"), "MassivePool"),
    ] as [(QuotaRoot, String)])
    func debugDescription(_ fixture: (QuotaRoot, String)) {
        #expect(fixture.0.debugDescription == fixture.1)
    }

    @Test func debugDescriptionInvalidUTF8() {
        // Invalid UTF-8 falls back to String(buffer:), which produces a non-nil description.
        let root = QuotaRoot(ByteBuffer(bytes: [0xFF, 0xFE]))
        // String(self) returns nil, so debugDescription uses the fallback path.
        #expect(String(root) == nil)
        #expect(root.debugDescription.isEmpty == false)
    }
}

// MARK: -

extension EncodeFixture<QuotaRoot> {
    fileprivate static func quotaRoot(_ input: QuotaRoot, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaRoot($1) }
        )
    }
}

extension ParseFixture<QuotaRoot> {
    fileprivate static func quotaRoot(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseQuotaRoot
        )
    }
}
