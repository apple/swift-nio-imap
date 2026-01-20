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
        EncodeFixture.bodyLanguages(["some1", "some2", "some3"], "(\"some1\" \"some2\" \"some3\")"),
    ])
    func encoding(_ fixture: EncodeFixture<[String]>) {
        fixture.checkEncoding()
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
