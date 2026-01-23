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
        ),
    ])
    func encode(_ fixture: EncodeFixture<UserAuthenticationMechanism>) {
        fixture.checkEncoding()
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
