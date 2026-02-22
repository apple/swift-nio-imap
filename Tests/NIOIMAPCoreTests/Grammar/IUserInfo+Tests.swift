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

@Suite("UserAuthenticationMechanism")
struct UserAuthenticationMechanismTests {
    @Test(arguments: [
        EncodeFixture.userAuthenticationMechanism(
            .init(encodedUser: .init(data: "test"), authenticationMechanism: .any),
            "test;AUTH=*"
        ),
        EncodeFixture.userAuthenticationMechanism(
            .init(encodedUser: .init(data: "test"), authenticationMechanism: nil),
            "test"
        ),
        EncodeFixture.userAuthenticationMechanism(
            .init(encodedUser: nil, authenticationMechanism: .any),
            ";AUTH=*"
        )
    ])
    func encode(_ fixture: EncodeFixture<UserAuthenticationMechanism>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.userAuthenticationMechanism(
            ";AUTH=*",
            " ",
            expected: .success(.init(encodedUser: nil, authenticationMechanism: .any))
        ),
        ParseFixture.userAuthenticationMechanism(
            "test",
            " ",
            expected: .success(.init(encodedUser: .init(data: "test"), authenticationMechanism: nil))
        ),
        ParseFixture.userAuthenticationMechanism(
            "test;AUTH=*",
            " ",
            expected: .success(.init(encodedUser: .init(data: "test"), authenticationMechanism: .any))
        )
    ])
    func parse(_ fixture: ParseFixture<UserAuthenticationMechanism>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<UserAuthenticationMechanism> {
    fileprivate static func userAuthenticationMechanism(
        _ input: UserAuthenticationMechanism,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeUserAuthenticationMechanism($1) }
        )
    }
}

extension ParseFixture<UserAuthenticationMechanism> {
    fileprivate static func userAuthenticationMechanism(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUserAuthenticationMechanism
        )
    }
}
