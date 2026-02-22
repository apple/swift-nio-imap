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

@Suite("AuthenticatedURLRump")
struct AuthenticatedURLRumpTests {
    @Test(arguments: [
        EncodeFixture.authenticatedURLRump(
            .init(access: .anonymous),
            ";URLAUTH=anonymous"
        ),
        EncodeFixture.authenticatedURLRump(
            .init(
                expire: .init(
                    dateTime: .init(
                        date: .init(year: 1234, month: 12, day: 23),
                        time: .init(hour: 12, minute: 34, second: 56)
                    )
                ),
                access: .authenticateUser
            ),
            ";EXPIRE=1234-12-23T12:34:56;URLAUTH=authuser"
        )
    ])
    func encode(_ fixture: EncodeFixture<AuthenticatedURLRump>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.authenticatedURLRump(
            ";URLAUTH=anonymous",
            " ",
            expected: .success(.init(access: .anonymous))
        ),
        ParseFixture.authenticatedURLRump(
            ";EXPIRE=1234-12-23T12:34:56;URLAUTH=anonymous",
            " ",
            expected: .success(
                .init(
                    expire: .init(
                        dateTime: .init(
                            date: .init(year: 1234, month: 12, day: 23),
                            time: .init(hour: 12, minute: 34, second: 56)
                        )
                    ),
                    access: .anonymous
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<AuthenticatedURLRump>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AuthenticatedURLRump> {
    fileprivate static func authenticatedURLRump(
        _ input: AuthenticatedURLRump,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAuthenticatedURLRump($1) }
        )
    }
}

extension ParseFixture<AuthenticatedURLRump> {
    fileprivate static func authenticatedURLRump(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthenticatedURLRump
        )
    }
}
