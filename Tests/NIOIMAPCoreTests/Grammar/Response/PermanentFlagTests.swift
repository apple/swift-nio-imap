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

@Suite("PermanentFlag")
struct PermanentFlagTests {
    @Test(arguments: [
        EncodeFixture.permanentFlag(.wildcard, #"\*"#),
        EncodeFixture.permanentFlag(.flag(.answered), #"\Answered"#)
    ])
    func encode(_ fixture: EncodeFixture<PermanentFlag>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<PermanentFlag> {
    fileprivate static func permanentFlag(
        _ input: PermanentFlag,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFlagPerm($1) }
        )
    }
}
