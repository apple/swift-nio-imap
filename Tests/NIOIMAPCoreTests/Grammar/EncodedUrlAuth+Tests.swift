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

@Suite("EncodedAuthenticatedURL")
struct EncodedAuthenticatedURLTests {
    @Test(arguments: [
        EncodeFixture.encodedAuthenticationURL(.init(data: "1F"), "1F"),
        EncodeFixture.encodedAuthenticationURL(.init(data: "ABC123"), "ABC123"),
    ])
    func encode(_ fixture: EncodeFixture<EncodedAuthenticatedURL>) {
        fixture.checkEncoding()
    }
}

extension EncodeFixture where T == EncodedAuthenticatedURL {
    fileprivate static func encodedAuthenticationURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeEncodedAuthenticationURL($1) }
        )
    }
}
