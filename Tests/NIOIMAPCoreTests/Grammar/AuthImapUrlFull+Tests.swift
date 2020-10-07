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

class AuthIMAPURLFull_Tests: EncodeTestClass {}

// MARK: - Encoding

extension AuthIMAPURLFull_Tests {
    func testEncoding() {
        let inputs: [(AuthIMAPURLFull, String, UInt)] = [
            (
                .init(imapUrl: .init(server: .init(host: "localhost"), messagePart: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123)!)), urlAuth: .init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedUrlAuth: .init(data: "data")))),
                "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:data",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAuthIMAPURLFull($0) })
    }
}
