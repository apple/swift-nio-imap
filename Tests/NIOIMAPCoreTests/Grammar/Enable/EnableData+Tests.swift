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

@Suite("EnableData")
struct EnableDataTests {
    @Test(arguments: [
        EncodeFixture.enableData(
            [],
            "ENABLED"
        ),
        EncodeFixture.enableData(
            [.enable],
            "ENABLED ENABLE"
        ),
        EncodeFixture.enableData(
            [.enable, .condStore],
            "ENABLED ENABLE CONDSTORE"
        ),
        EncodeFixture.enableData(
            [.enable, .condStore, .authenticate(.init("some"))],
            "ENABLED ENABLE CONDSTORE AUTH=SOME"
        ),
    ])
    func encode(_ fixture: EncodeFixture<[Capability]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<[Capability]> {
    fileprivate static func enableData(
        _ input: [Capability],
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEnableData($1) }
        )
    }
}
