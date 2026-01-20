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
        ),
    ])
    func encoding(_ fixture: EncodeFixture<BodyStructure.Fields>) {
        fixture.checkEncoding()
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
