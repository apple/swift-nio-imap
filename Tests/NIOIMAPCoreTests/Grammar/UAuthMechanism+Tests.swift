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

@Suite("URLAuthenticationMechanism")
struct URLAuthenticationMechanismTests {
    @Test(arguments: [
        EncodeFixture.urlAuthenticationMechanism(
            .internal,
            "INTERNAL"
        ),
        EncodeFixture.urlAuthenticationMechanism(
            .init("test"),
            "test"
        ),
    ])
    func encode(_ fixture: EncodeFixture<URLAuthenticationMechanism>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<URLAuthenticationMechanism> {
    fileprivate static func urlAuthenticationMechanism(
        _ input: URLAuthenticationMechanism,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLAuthenticationMechanism($1) }
        )
    }
}
