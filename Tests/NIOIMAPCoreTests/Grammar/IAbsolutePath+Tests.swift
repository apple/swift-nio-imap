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

@Suite("AbsoluteMessagePath")
struct AbsoluteMessagePathTests {
    @Test(arguments: [
        EncodeFixture.absoluteMessagePath(
            .init(command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))),
            "/test"
        ),
        EncodeFixture.absoluteMessagePath(
            .init(command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "INBOX"))))),
            "/INBOX"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AbsoluteMessagePath>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture where T == AbsoluteMessagePath {
    fileprivate static func absoluteMessagePath(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeAbsoluteMessagePath($1) }
        )
    }
}
