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

@Suite("Patterns")
struct PatternsTests {
    @Test(arguments: [
        EncodeFixture.patterns(["Mailbox1", "Mailbox2"], "(\"Mailbox1\" \"Mailbox2\")"),
        EncodeFixture.patterns(["*"], "(\"*\")"),
    ])
    func encode(_ fixture: EncodeFixture<[ByteBuffer]>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture where T == [ByteBuffer] {
    fileprivate static func patterns(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writePatterns($1) }
        )
    }
}
