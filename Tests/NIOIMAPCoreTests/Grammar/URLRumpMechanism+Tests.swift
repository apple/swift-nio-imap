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

@Suite("RumpURLAndMechanism")
struct RumpURLAndMechanismTests {
    @Test(arguments: [
        EncodeFixture.rumpURLAndMechanism(
            .init(urlRump: "test", mechanism: .internal),
            "\"test\" INTERNAL"
        ),
        EncodeFixture.rumpURLAndMechanism(
            .init(urlRump: "server.example.com", mechanism: .internal),
            "\"server.example.com\" INTERNAL"
        ),
    ])
    func encode(_ fixture: EncodeFixture<RumpURLAndMechanism>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.rumpURLAndMechanism(
            "test INTERNAL",
            " ",
            expected: .success(.init(urlRump: "test", mechanism: .internal))
        ),
        ParseFixture.rumpURLAndMechanism(
            "\"test\" INTERNAL",
            " ",
            expected: .success(.init(urlRump: "test", mechanism: .internal))
        ),
        ParseFixture.rumpURLAndMechanism(
            "{4}\r\ntest INTERNAL",
            " ",
            expected: .success(.init(urlRump: "test", mechanism: .internal))
        ),
    ])
    func parse(_ fixture: ParseFixture<RumpURLAndMechanism>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<RumpURLAndMechanism> {
    fileprivate static func rumpURLAndMechanism(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeURLRumpMechanism($1) }
        )
    }
}

extension ParseFixture<RumpURLAndMechanism> {
    fileprivate static func rumpURLAndMechanism(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseURLRumpMechanism
        )
    }
}
