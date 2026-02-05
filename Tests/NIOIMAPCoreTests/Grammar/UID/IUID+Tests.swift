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

@Suite("IUID")
struct IUIDTests {
    @Test(arguments: [
        EncodeFixture.iuid(.init(uid: 123), "/;UID=123"),
    ])
    func encode(_ fixture: EncodeFixture<IUID>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.iuidOnly(.init(uid: 123), ";UID=123"),
    ])
    func `encode UID only`(_ fixture: EncodeFixture<IUID>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<IUID> {
    fileprivate static func iuid(
        _ input: IUID,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIUID($1) }
        )
    }

    fileprivate static func iuidOnly(
        _ input: IUID,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIUIDOnly($1) }
        )
    }
}
