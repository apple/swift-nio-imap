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

@Suite("QuotaLimit")
struct QuotaLimitTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.quotaLimit(QuotaLimit(resourceName: "STORAGE", limit: 104), "STORAGE 104"),
            EncodeFixture.quotaLimit(QuotaLimit(resourceName: "MESSAGE", limit: 42), "MESSAGE 42"),
        ]
    )
    func encode(_ fixture: EncodeFixture<QuotaLimit>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse LIST",
        arguments: [
            ParseFixture.quotaLimits("()", expected: .success([])),
            ParseFixture.quotaLimits(
                "(STORAGE 104)",
                expected: .success([QuotaLimit(resourceName: "STORAGE", limit: 104)])
            ),
            ParseFixture.quotaLimits(
                "(STORAGE 104 MESSAGE 42)",
                expected: .success([
                    QuotaLimit(resourceName: "STORAGE", limit: 104),
                    QuotaLimit(resourceName: "MESSAGE", limit: 42),
                ])
            ),
            ParseFixture.quotaLimits("", "", expected: .incompleteMessage),
            ParseFixture.quotaLimits("STORAGE 104", expected: .failure),
        ]
    )
    func parseList(_ fixture: ParseFixture<[QuotaLimit]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<QuotaLimit> {
    fileprivate static func quotaLimit(_ input: QuotaLimit, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaLimit($1) }
        )
    }
}

extension ParseFixture<[QuotaLimit]> {
    fileprivate static func quotaLimits(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseQuotaLimits
        )
    }
}
