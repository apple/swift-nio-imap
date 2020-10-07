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

class ICommand_Tests: EncodeTestClass {}

// MARK: - IMAP

extension ICommand_Tests {
    func testEncode() {
        let inputs: [(ICommand, String, UInt)] = [
            (.messageList(.init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")))), "test", #line),
            (.messagePart(part: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123)), urlAuth: nil), "test/;UID=123", #line),
            (.messagePart(part: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123)), urlAuth: .init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedUrlAuth: .init(data: "01234567890123456789012345678901")))), "test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeICommand($0) })
    }
}
