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

@Suite("QuotaResource")
struct QuotaResourceTests {
    @Test(arguments: [
        EncodeFixture.quotaResource(QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512), "STORAGE 10 512"),
        EncodeFixture.quotaResource(QuotaResource(resourceName: "MESSAGE", usage: 0, limit: 1000), "MESSAGE 0 1000"),
        EncodeFixture.quotaResource(
            QuotaResource(resourceName: "ATTACHMENT", usage: 999_999_999, limit: 1_000_000_000),
            "ATTACHMENT 999999999 1000000000"
        )
    ])
    func encode(_ fixture: EncodeFixture<QuotaResource>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<QuotaResource> {
    fileprivate static func quotaResource(_ input: QuotaResource, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaResource($1) }
        )
    }
}
