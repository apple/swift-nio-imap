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

@Suite("AuthenticatedURL")
struct AuthenticatedURLTests {
    @Test(arguments: [
        EncodeFixture.authenticatedURL(
            .init(
                authenticatedURL: .init(access: .anonymous),
                verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "test"))
            ),
            ";URLAUTH=anonymous:INTERNAL:test"
        ),
        EncodeFixture.authenticatedURL(
            .init(
                authenticatedURL: .init(access: .user(.init(data: "alice"))),
                verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "verifier456"))
            ),
            ";URLAUTH=user+alice:INTERNAL:verifier456"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AuthenticatedURL>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<AuthenticatedURL> {
    fileprivate static func authenticatedURL(
        _ input: AuthenticatedURL,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIAuthenticatedURL($1) }
        )
    }
}
