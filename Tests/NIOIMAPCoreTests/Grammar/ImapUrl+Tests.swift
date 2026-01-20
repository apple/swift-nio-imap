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

@Suite("IMAPURL")
struct IMAPURLTests {
    @Test(arguments: [
        EncodeFixture.imapURL(
            .init(server: .init(host: "localhost"), query: nil),
            "imap://localhost/"
        ),
        EncodeFixture.imapURL(
            .init(server: .init(host: "mail.example.com"), query: nil),
            "imap://mail.example.com/"
        ),
    ])
    func encode(_ fixture: EncodeFixture<IMAPURL>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture<IMAPURL> {
    fileprivate static func imapURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeIMAPURL($1) }
        )
    }
}
