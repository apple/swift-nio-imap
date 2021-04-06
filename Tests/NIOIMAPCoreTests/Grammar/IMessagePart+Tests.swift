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
@testable import NIOIMAPCore
import XCTest

class IMessagePart_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IMessagePart_Tests {
    func testEncode() {
        let inputs: [(IMessagePart, String, UInt)] = [
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), IMAPURLSection: nil, iPartial: nil),
                "test/;UID=123",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), IMAPURLSection: .init(encodedSection: .init(section: "section")), iPartial: nil),
                "test/;UID=123/;SECTION=section",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), IMAPURLSection: nil, iPartial: .init(range: .init(offset: 123, length: 4))),
                "test/;UID=123/;PARTIAL=123.4",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), IMAPURLSection: .init(encodedSection: .init(section: "section")), iPartial: .init(range: .init(offset: 123, length: 4))),
                "test/;UID=123/;SECTION=section/;PARTIAL=123.4",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMessagePart($0) })
    }
}
