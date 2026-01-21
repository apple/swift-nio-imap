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

@Suite("UIDValidity")
struct UIDValidityTests {
    @Test(arguments: [
        EncodeFixture.uidValidity(1, "1"),
        EncodeFixture.uidValidity(123, "123"),
        EncodeFixture.uidValidity(4_294_967_295, "4294967295"),
    ])
    func encode(_ fixture: EncodeFixture<UIDValidity>) {
        fixture.checkEncoding()
    }

    @Test
    func `valid range`() {
        #expect(UIDValidity(exactly: 0) == nil)
        #expect(UIDValidity(exactly: 1)?.rawValue == 1)
        #expect(UIDValidity(exactly: 4_294_967_295)?.rawValue == 4_294_967_295)
        #expect(UIDValidity(exactly: 4_294_967_296) == nil)
    }
}

// MARK: -

extension EncodeFixture<UIDValidity> {
    fileprivate static func uidValidity(_ input: UIDValidity, _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeUIDValidity($1) })
    }
}
