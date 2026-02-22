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

@Suite("ScopeOption")
struct ScopeOptionTests {
    @Test(arguments: [
        EncodeFixture.scopeOption(
            .zero,
            "DEPTH 0"
        ),
        EncodeFixture.scopeOption(
            .one,
            "DEPTH 1"
        ),
        EncodeFixture.scopeOption(
            .infinity,
            "DEPTH infinity"
        )
    ])
    func encode(_ fixture: EncodeFixture<ScopeOption>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.scopeOption("DEPTH 0", expected: .success(.zero)),
        ParseFixture.scopeOption("DEPTH 1", expected: .success(.one)),
        ParseFixture.scopeOption("DEPTH infinity", expected: .success(.infinity))
    ])
    func parse(_ fixture: ParseFixture<ScopeOption>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ScopeOption> {
    fileprivate static func scopeOption(
        _ input: ScopeOption,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeScopeOption($1) }
        )
    }
}

extension ParseFixture<ScopeOption> {
    fileprivate static func scopeOption(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseScopeOption
        )
    }
}
