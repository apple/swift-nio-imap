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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("EncodedAuthenticationType")
struct EncodedAuthenticationTypeTests {
    @Test(arguments: [
        EncodeFixture.encodedAuthenticationType(.init(authenticationType: "hello"), "hello"),
    ])
    func encode(_ fixture: EncodeFixture<EncodedAuthenticationType>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedAuthenticationType(
            "hello%FF",
            " ",
            expected: .success(.init(authenticationType: "hello%FF"))
        ),
    ])
    func parse(_ fixture: ParseFixture<EncodedAuthenticationType>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EncodedAuthenticationType> {
    fileprivate static func encodedAuthenticationType(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedAuthenticationType($1) }
        )
    }
}

extension ParseFixture<EncodedAuthenticationType> {
    fileprivate static func encodedAuthenticationType(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedAuthenticationType
        )
    }
}
