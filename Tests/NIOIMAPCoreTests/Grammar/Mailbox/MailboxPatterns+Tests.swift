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

@Suite("MailboxPatterns")
struct MailboxPatternsTests {
    @Test(arguments: [
        EncodeFixture.mailboxPatterns(.mailbox("inbox"), #""inbox""#),
        EncodeFixture.mailboxPatterns(.pattern(["pattern"]), #"("pattern")"#),
        EncodeFixture.mailboxPatterns(.pattern(["aa", "bb"]), #"("aa" "bb")"#)
    ])
    func encode(_ fixture: EncodeFixture<MailboxPatterns>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MailboxPatterns> {
    fileprivate static func mailboxPatterns(
        _ input: MailboxPatterns,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxPatterns($1) }
        )
    }
}
