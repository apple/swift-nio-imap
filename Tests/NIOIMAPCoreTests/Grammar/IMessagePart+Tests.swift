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

class MessagePath_Tests: EncodeTestClass {}

// MARK: - IMAP

extension MessagePath_Tests {
    func testEncode() {
        let inputs: [(MessagePath, String, UInt)] = [
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), section: nil, range: nil),
                "test/;UID=123",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), section: .init(encodedSection: .init(section: "section")), range: nil),
                "test/;UID=123/;SECTION=section",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), section: nil, range: .init(range: .init(offset: 123, length: 4))),
                "test/;UID=123/;PARTIAL=123.4",
                #line
            ),
            (
                .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123), section: .init(encodedSection: .init(section: "section")), range: .init(range: .init(offset: 123, length: 4))),
                "test/;UID=123/;SECTION=section/;PARTIAL=123.4",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMessagePath($0) })
    }
}
