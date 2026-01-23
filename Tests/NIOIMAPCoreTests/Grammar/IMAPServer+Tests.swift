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

@Suite("IMAP Server")
struct IMAPServerTests {
    @Test(arguments: [
        EncodeFixture.imapServer(.init(host: "localhost"), "localhost"),
        EncodeFixture.imapServer(
            .init(
                userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                host: "localhost"
            ),
            ";AUTH=*@localhost"
        ),
        EncodeFixture.imapServer(.init(host: "localhost", port: 1234), "localhost:1234"),
        EncodeFixture.imapServer(
            .init(
                userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                host: "localhost",
                port: 1234
            ),
            ";AUTH=*@localhost:1234"
        ),
    ])
    func encode(_ fixture: EncodeFixture<IMAPServer>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<IMAPServer> {
    fileprivate static func imapServer(
        _ input: IMAPServer,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIMAPServer($1) }
        )
    }
}
