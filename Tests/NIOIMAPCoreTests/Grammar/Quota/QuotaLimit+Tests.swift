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
    @Test(arguments: [
        EncodeFixture.quotaLimit(QuotaLimit(resourceName: "STORAGE", limit: 104), "STORAGE 104"),
        EncodeFixture.quotaLimit(QuotaLimit(resourceName: "MESSAGE", limit: 42), "MESSAGE 42"),
    ])
    func encode(_ fixture: EncodeFixture<QuotaLimit>) {
        fixture.checkEncoding()
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
