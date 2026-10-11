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

@Suite("RumpAuthenticatedURL")
struct RumpAuthenticatedURLTests {
    @Test(arguments: [
        ParseFixture.rumpAuthenticatedURL(
            "imap://localhost/test/;UID=123;URLAUTH=anonymous",
            " ",
            expected: .success(
                .init(
                    authenticatedURL: .init(
                        server: .init(host: "localhost"),
                        messagePath: .init(
                            mailboxReference: .init(encodeMailbox: "test"),
                            iUID: .init(uid: 123)
                        )
                    ),
                    authenticatedURLRump: .init(access: .anonymous)
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<RumpAuthenticatedURL>) {
        fixture.checkParsing()
    }
}

extension ParseFixture<RumpAuthenticatedURL> {
    fileprivate static func rumpAuthenticatedURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthIMAPURLRump
        )
    }
}
