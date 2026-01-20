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

@Suite("CreateParameter")
struct CreateParameterTests {
    @Test(arguments: [
        EncodeFixture.createParameter(
            .labelled(.init(key: "name", value: nil)),
            "name"
        ),
        EncodeFixture.createParameter(
            .labelled(.init(key: "name", value: .sequence(.set([1])))),
            "name 1"
        ),
        EncodeFixture.createParameter(
            .attributes([]),
            "USE ()"
        ),
        EncodeFixture.createParameter(
            .attributes([.all]),
            "USE (\\All)"
        ),
        EncodeFixture.createParameter(
            .attributes([.all, .flagged]),
            "USE (\\All \\Flagged)"
        ),
    ])
    func encode(_ fixture: EncodeFixture<CreateParameter>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<CreateParameter> {
    fileprivate static func createParameter(
        _ input: CreateParameter,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCreateParameter($1) }
        )
    }
}
