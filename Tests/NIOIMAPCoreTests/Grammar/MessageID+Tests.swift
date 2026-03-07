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

@Suite("MessageID")
struct MessageIDTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.messageID(.init("<foo@bar.com>"), "\"<foo@bar.com>\""),
            EncodeFixture.messageID(
                .init("<B27397-0100000@cac.washington.edu>"),
                "\"<B27397-0100000@cac.washington.edu>\""
            ),
        ]
    )
    func encode(_ fixture: EncodeFixture<MessageID>) {
        fixture.checkEncoding()
    }

    @Test("string conversion")
    func stringConversion() {
        let id = MessageID("<foo@example.com>")
        #expect(String(id) == "<foo@example.com>")
    }
}

// MARK: -

extension EncodeFixture<MessageID> {
    fileprivate static func messageID(_ input: MessageID, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageID($1) }
        )
    }
}
