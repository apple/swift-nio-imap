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
import OrderedCollections
import Testing

@Suite("BodyStructure.Parameters")
struct BodyFieldParameterTests {
    @Test(arguments: [
        EncodeFixture.bodyParameterPairs([:], "NIL"),
        EncodeFixture.bodyParameterPairs(["f1": "v1"], "(\"f1\" \"v1\")"),
        EncodeFixture.bodyParameterPairs(["f1": "v1", "f2": "v2"], "(\"f1\" \"v1\" \"f2\" \"v2\")"),
    ])
    func encoding(_ fixture: EncodeFixture<OrderedDictionary<String, String>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.bodyParameterPairs(#"NIL"#, " ", expected: .success([:])),
        ParseFixture.bodyParameterPairs(#"("f1" "v1")"#, " ", expected: .success(["f1": "v1"])),
        ParseFixture.bodyParameterPairs(#"("f1" "v1" "f2" "v2")"#, " ", expected: .success(["f1": "v1", "f2": "v2"])),
        ParseFixture.bodyParameterPairs(
            "(\"NAME\" \"Nutzungsbedingungen f\u{C3}\u{83}\u{C2}\u{83}\u{C3}\u{82}\u{C2}\u{BC}r Meine Allianz.pdf\")",
            " ",
            expected: .success([
                "NAME": "Nutzungsbedingungen f\u{C3}\u{83}\u{C2}\u{83}\u{C3}\u{82}\u{C2}\u{BC}r Meine Allianz.pdf"
            ])
        ),
        ParseFixture.bodyParameterPairs(#"("p1" "#, "", expected: .incompleteMessageIgnoringBufferModifications),
    ])
    func parse(_ fixture: ParseFixture<OrderedDictionary<String, String>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<OrderedDictionary<String, String>> {
    fileprivate static func bodyParameterPairs(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyParameterPairs($1) }
        )
    }
}

extension ParseFixture<OrderedDictionary<String, String>> {
    fileprivate static func bodyParameterPairs(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyFieldParam
        )
    }
}
