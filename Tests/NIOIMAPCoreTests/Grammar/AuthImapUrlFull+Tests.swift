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
import XCTest

class AuthIMAPURLFull_Tests: EncodeTestClass {}

// MARK: - Encoding

extension AuthIMAPURLFull_Tests {
    func testEncoding() {
        let inputs: [(FullAuthenticatedURL, String, UInt)] = [
            (
                .init(networkMessagePath: .init(server: .init(host: "localhost"), messagePath: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123))), authenticatedURL: .init(authenticatedURL: .init(access: .anonymous), verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "data")))),
                "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:data",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAuthIMAPURLFull($0) })
    }
}
