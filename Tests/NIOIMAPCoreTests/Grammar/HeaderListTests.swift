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

@Suite("Header Lists")
struct HeaderListsTests {
    @Test(arguments: [
        EncodeFixture.headerList([], "()"),
        EncodeFixture.headerList(["hello", "there", "world"], #"("hello" "there" "world")"#)
    ])
    func encode(_ fixture: EncodeFixture<[String]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.headerList(#"("field")"#, expected: .success(["field"])),
        ParseFixture.headerList(#"("first" "second" "third")"#, expected: .success(["first", "second", "third"])),
        ParseFixture.headerList("()", "\r", expected: .failureIgnoringBufferModifications)
    ])
    func parse(_ fixture: ParseFixture<[String]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[String]> {
    fileprivate static func headerList(
        _ input: [String],
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeHeaderList($1) }
        )
    }
}

extension ParseFixture<[String]> {
    fileprivate static func headerList(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseHeaderList
        )
    }
}
