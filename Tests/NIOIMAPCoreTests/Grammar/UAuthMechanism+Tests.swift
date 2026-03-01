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

    @Test(arguments: [
        ParseFixture.urlAuthenticationMechanism(
            "INTERNAL",
            " ",
            expected: .success(.internal)
        ),
        ParseFixture.urlAuthenticationMechanism(
            "abcdEFG0123456789",
            " ",
            expected: .success(.init("abcdEFG0123456789"))
        ),
    ])
    func parse(_ fixture: ParseFixture<URLAuthenticationMechanism>) {
        fixture.checkParsing()
    }

    @Test("string conversion")
    func stringConversion() {
        #expect(String(URLAuthenticationMechanism.internal) == "INTERNAL")
        #expect(String(URLAuthenticationMechanism("CUSTOM")) == "CUSTOM")
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

extension ParseFixture<URLAuthenticationMechanism> {
    fileprivate static func urlAuthenticationMechanism(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUAuthMechanism
        )
    }
}
