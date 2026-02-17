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

@Suite("BodyStructure.Fields")
struct BodyFieldsTests {
    @Test(arguments: [
        EncodeFixture.bodyFields(
            .init(
                parameters: ["f1": "v1"],
                id: "fieldID",
                contentDescription: "desc",
                encoding: .base64,
                octetCount: 12
            ),
            "(\"f1\" \"v1\") \"fieldID\" \"desc\" \"BASE64\" 12"
        )
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.Fields>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.bodyFields(
            #"("f1" "v1") "id" "desc" "8BIT" 1234"#,
            " ",
            expected: .success(
                BodyStructure.Fields(
                    parameters: ["f1": "v1"],
                    id: "id",
                    contentDescription: "desc",
                    encoding: .eightBit,
                    octetCount: 1234
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<BodyStructure.Fields>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.Fields> {
    fileprivate static func bodyFields(_ input: T, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeBodyFields($1) }
        )
    }
}

extension ParseFixture<BodyStructure.Fields> {
    fileprivate static func bodyFields(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyFields
        )
    }
}
