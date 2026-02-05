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

@Suite("MessageData")
struct MessageDataTests {
    @Test(arguments: [
        EncodeFixture.messageData(.expunge(123), "123 EXPUNGE"),
        EncodeFixture.messageData(.vanished(.all), "VANISHED 1:*"),
        EncodeFixture.messageData(.vanishedEarlier(.all), "VANISHED (EARLIER) 1:*"),
        EncodeFixture.messageData(.generateAuthorizedURL(["test"]), #"GENURLAUTH "test""#),
        EncodeFixture.messageData(.generateAuthorizedURL(["test1", "test2"]), #"GENURLAUTH "test1" "test2""#),
    ])
    func encode(_ fixture: EncodeFixture<MessageData>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MessageData> {
    fileprivate static func messageData(
        _ input: MessageData,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMessageData($1) }
        )
    }
}
