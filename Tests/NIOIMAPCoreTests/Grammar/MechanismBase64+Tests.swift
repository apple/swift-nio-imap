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
