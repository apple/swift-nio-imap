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

@Suite("ListSelectIndependentOption")
struct ListSelectIndependentOptionTests {
    @Test(arguments: [
        EncodeFixture.listSelectIndependentOption(.remote, "REMOTE"),
        EncodeFixture.listSelectIndependentOption(.option(.init(key: .standard("test"), value: nil)), "test"),
        EncodeFixture.listSelectIndependentOption(.specialUse, "SPECIAL-USE"),
    ])
    func encode(_ fixture: EncodeFixture<ListSelectIndependentOption>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ListSelectIndependentOption> {
    fileprivate static func listSelectIndependentOption(
        _ input: ListSelectIndependentOption,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectIndependentOption($1) }
        )
    }
}
