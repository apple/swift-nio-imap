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

@Suite("EnableData")
struct EnableDataTests {
    @Test(arguments: [
        EncodeFixture.enableData(
            [],
            "ENABLED"
        ),
        EncodeFixture.enableData(
            [.enable],
            "ENABLED ENABLE"
        ),
        EncodeFixture.enableData(
            [.enable, .condStore],
            "ENABLED ENABLE CONDSTORE"
        ),
        EncodeFixture.enableData(
            [.enable, .condStore, .authenticate(.init("some"))],
            "ENABLED ENABLE CONDSTORE AUTH=SOME"
        ),
    ])
    func encode(_ fixture: EncodeFixture<[Capability]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.enableData("ENABLED", expected: .success([])),
        ParseFixture.enableData("ENABLED ENABLE", expected: .success([.enable])),
        ParseFixture.enableData("ENABLED UTF8=ACCEPT", expected: .success([.utf8(.accept)])),
        ParseFixture.enableData("ENABLED ENABLE CONDSTORE", expected: .success([.enable, .condStore])),
    ])
    func parse(_ fixture: ParseFixture<[Capability]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[Capability]> {
    fileprivate static func enableData(
        _ input: [Capability],
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEnableData($1) }
        )
    }
}

extension ParseFixture<[Capability]> {
    fileprivate static func enableData(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEnableData
        )
    }
}
