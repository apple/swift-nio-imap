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

class URLCommand_Tests: EncodeTestClass {}

// MARK: - IMAP

extension URLCommand_Tests {
    func testEncode() {
        let inputs: [(URLCommand, String, UInt)] = [
            (.messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test")))), "test", #line),
            (.fetch(path: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123)), authenticatedURL: nil), "test/;UID=123", #line),
            (.fetch(path: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123)), authenticatedURL: .init(authenticatedURL: .init(access: .anonymous), verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")))), "test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeURLCommand($0) })
    }
}
