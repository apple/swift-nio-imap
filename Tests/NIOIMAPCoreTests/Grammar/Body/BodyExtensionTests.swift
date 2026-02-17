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

@Suite("BodyExtension")
struct BodyExtensionTests {
    @Test(arguments: [
        EncodeFixture.bodyExtensions([.number(1)], "(1)"),
        EncodeFixture.bodyExtensions([.string("apple")], "(\"apple\")"),
        EncodeFixture.bodyExtensions([.string(nil)], "(NIL)"),
        EncodeFixture.bodyExtensions([.number(1), .number(2), .string("three")], "(1 2 \"three\")"),
        EncodeFixture.bodyExtensions(
            [.number(1), .number(2), .string("three"), .string("four")],
            "(1 2 \"three\" \"four\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<[BodyExtension]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.bodyExtension("1", expected: .success([.number(1)])),
        ParseFixture.bodyExtension(#""s""#, expected: .success([.string("s")])),
        ParseFixture.bodyExtension("(1)", expected: .success([.number(1)])),
        ParseFixture.bodyExtension("(1 \"2\" 3)", expected: .success([.number(1), .string("2"), .number(3)])),
        ParseFixture.bodyExtension(
            "(1 2 3 (4 (5 (6))))",
            expected: .success([.number(1), .number(2), .number(3), .number(4), .number(5), .number(6)])
        ),
        ParseFixture.bodyExtension("(((((1)))))", expected: .success([.number(1)])),
    ])
    func parse(_ fixture: ParseFixture<[BodyExtension]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[BodyExtension]> {
    fileprivate static func bodyExtensions(_ input: [BodyExtension], _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeBodyExtensions($1) }
        )
    }
}

extension ParseFixture<[BodyExtension]> {
    fileprivate static func bodyExtension(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyExtension
        )
    }
}
