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

class RelativeIMAPURL_Tests: EncodeTestClass {}

// MARK: - IMAP

extension RelativeIMAPURL_Tests {
    func testEncode() {
        let inputs: [(RelativeIMAPURL, String, UInt)] = [
            (.absolutePath(.init(command: .messageList(.init(mailboxValidity: .init(encodeMailbox: .init(mailbox: "test")))))), "/test", #line),
            (.networkPath(.init(server: .init(host: "localhost"), query: .init(command: nil))), "//localhost/", #line),
            (.relativePath(.list(.init(mailboxValidity: .init(encodeMailbox: .init(mailbox: "test"))))), "test", #line),
            (.empty, "", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeRelativeIMAPURL($0) })
    }
}
