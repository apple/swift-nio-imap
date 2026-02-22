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
        EncodeFixture.quotaRoot(QuotaRoot("MassivePool"), #""MassivePool""#)
    ])
    func encode(_ fixture: EncodeFixture<QuotaRoot>) {
        fixture.checkEncoding()
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
