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

class AuthIMAPURL_Tests: EncodeTestClass {}

// MARK: - Encoding

extension AuthIMAPURL_Tests {
    func testEncoding() {
        let inputs: [(AuthIMAPURL, String, UInt)] = [
            (
                .init(server: .init(host: "localhost"), messagePart: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: try! .init(uid: 123))),
                "imap://localhost/test/;UID=123",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAuthIMAPURL($0) })
    }
}
