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

@Suite("IMAPURLAuthenticationMechanism")
struct IMAPURLAuthenticationMechanismTests {
    @Test(arguments: [
        EncodeFixture.imapURLAuthenticationMechanism(.any, ";AUTH=*"),
        EncodeFixture.imapURLAuthenticationMechanism(.type(.init(authenticationType: "data")), ";AUTH=data"),
    ])
    func encode(_ fixture: EncodeFixture<IMAPURLAuthenticationMechanism>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.imapURLAuthenticationMechanism(";AUTH=*", " ", expected: .success(.any)),
        ParseFixture.imapURLAuthenticationMechanism(";AUTH=test", " ", expected: .success(.type(.init(authenticationType: "test")))),
    ])
    func parse(_ fixture: ParseFixture<IMAPURLAuthenticationMechanism>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<IMAPURLAuthenticationMechanism> {
    fileprivate static func imapURLAuthenticationMechanism(_ input: IMAPURLAuthenticationMechanism, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIMAPURLAuthenticationMechanism($1) }
        )
    }
}

extension ParseFixture<IMAPURLAuthenticationMechanism> {
    fileprivate static func imapURLAuthenticationMechanism(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIMAPURLAuthenticationMechanism
        )
    }
}
