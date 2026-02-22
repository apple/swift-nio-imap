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

@Suite("BodyStructure.Languages")
struct BodyFieldLanguageTests {
    @Test(arguments: [
        EncodeFixture.bodyLanguages([], "NIL"),
        EncodeFixture.bodyLanguages(["some1"], "(\"some1\")"),
        EncodeFixture.bodyLanguages(["some1", "some2", "some3"], "(\"some1\" \"some2\" \"some3\")")
    ])
    func encoding(_ fixture: EncodeFixture<[String]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.bodyFieldLanguage(#""english""#, expected: .success(["english"])),
        ParseFixture.bodyFieldLanguage(#"("english")"#, expected: .success(["english"])),
        ParseFixture.bodyFieldLanguage(#"("english" "french")"#, expected: .success(["english", "french"]))
    ])
    func parse(_ fixture: ParseFixture<[String]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<[String]> {
    fileprivate static func bodyLanguages(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyLanguages($1) }
        )
    }
}

extension ParseFixture<[String]> {
    fileprivate static func bodyFieldLanguage(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyFieldLanguage
        )
    }
}
