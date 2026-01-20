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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ReturnOption")
struct ReturnOptionTests {
    @Test(arguments: [
        EncodeFixture.returnOption(.subscribed, "SUBSCRIBED"),
        EncodeFixture.returnOption(.children, "CHILDREN"),
        EncodeFixture.returnOption(.statusOption([.messageCount]), "STATUS (MESSAGES)"),
        EncodeFixture.returnOption(.optionExtension(.init(key: .standard("atom"), value: nil)), "atom"),
        EncodeFixture.returnOption(.specialUse, "SPECIAL-USE"),
    ])
    func encode(_ fixture: EncodeFixture<ReturnOption>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == ReturnOption {
    fileprivate static func returnOption(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeReturnOption($1) }
        )
    }
}
