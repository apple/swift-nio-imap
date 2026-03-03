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

@Suite("Access")
struct AccessTests {
    @Test(arguments: [
        EncodeFixture.access(
            .anonymous,
            "anonymous"
        ),
        EncodeFixture.access(
            .authenticateUser,
            "authuser"
        ),
        EncodeFixture.access(
            .submit(.init(data: "abc")),
            "submit+abc"
        ),
        EncodeFixture.access(
            .user(.init(data: "abc")),
            "user+abc"
        ),
    ])
    func encode(_ fixture: EncodeFixture<Access>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.access(
            "authuser",
            "",
            expected: .success(.authenticateUser)
        ),
        ParseFixture.access(
            "anonymous",
            "",
            expected: .success(.anonymous)
        ),
        ParseFixture.access(
            "submit+abc",
            " ",
            expected: .success(.submit(.init(data: "abc")))
        ),
        ParseFixture.access(
            "user+abc",
            " ",
            expected: .success(.user(.init(data: "abc")))
        ),
    ])
    func parse(_ fixture: ParseFixture<Access>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<Access> {
    fileprivate static func access(
        _ input: Access,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAccess($1) }
        )
    }
}

extension ParseFixture<Access> {
    fileprivate static func access(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAccess
        )
    }
}
