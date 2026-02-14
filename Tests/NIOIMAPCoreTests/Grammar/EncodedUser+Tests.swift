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

@Suite("EncodedUser")
struct EncodedUserTests {
    @Test(arguments: [
        EncodeFixture.encodedUser(.init(data: "hello"), "hello"),
        EncodeFixture.encodedUser(.init(data: "test@example.com"), "test@example.com"),
    ])
    func encode(_ fixture: EncodeFixture<EncodedUser>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedUser(
            "query%FF",
            " ",
            expected: .success(.init(data: "query%FF"))
        ),
    ])
    func parse(_ fixture: ParseFixture<EncodedUser>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<EncodedUser> {
    fileprivate static func encodedUser(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeEncodedUser($1) }
        )
    }
}

extension ParseFixture<EncodedUser> {
    fileprivate static func encodedUser(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedUser
        )
    }
}
