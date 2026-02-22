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

@Suite("QuotaRootResponse")
struct QuotaRootResponseTests {
    @Test(arguments: [
        EncodeFixture.quotaRootResponse(
            MailboxName("INBOX"),
            QuotaRoot("Root"),
            #"QUOTAROOT "INBOX" "Root""#
        ),
        EncodeFixture.quotaRootResponse(
            MailboxName("INBOX"),
            QuotaRoot("#user/alice"),
            ##"QUOTAROOT "INBOX" "#user/alice""##
        ),
    ])
    func encode(_ fixture: EncodeFixture<(MailboxName, QuotaRoot)>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<(MailboxName, QuotaRoot)> {
    fileprivate static func quotaRootResponse(
        _ mailbox: MailboxName,
        _ quotaRoot: QuotaRoot,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: (mailbox, quotaRoot),
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeQuotaRootResponse(mailbox: $1.0, quotaRoot: $1.1) }
        )
    }
}
