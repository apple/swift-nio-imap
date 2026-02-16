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

@Suite("MechanismBase64")
struct MechanismBase64Tests {
    @Test(arguments: [
        EncodeFixture.mechanismBase64(
            .init(mechanism: .internal, base64: nil),
            "INTERNAL"
        ),
        EncodeFixture.mechanismBase64(
            .init(mechanism: .internal, base64: "base64"),
            "INTERNAL=base64"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MechanismBase64>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.mechanismBase64("INTERNAL", " ", expected: .success(.init(mechanism: .internal, base64: nil))),
        ParseFixture.mechanismBase64("INTERNAL=YQ==", " ", expected: .success(.init(mechanism: .internal, base64: "a"))),
    ])
    func parse(_ fixture: ParseFixture<MechanismBase64>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MechanismBase64> {
    fileprivate static func mechanismBase64(
        _ input: MechanismBase64,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMechanismBase64($1) }
        )
    }
}

extension ParseFixture<MechanismBase64> {
    fileprivate static func mechanismBase64(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMechanismBase64
        )
    }
}
