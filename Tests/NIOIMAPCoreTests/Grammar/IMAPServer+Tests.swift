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

class IMAPServer_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IMAPServer_Tests {
    func testEncode() {
        let inputs: [(IMAPServer, String, UInt)] = [
            (.init(host: "localhost"), "localhost", #line),
            (.init(userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any), host: "localhost"), ";AUTH=*@localhost", #line),
            (.init(host: "localhost", port: 1234), "localhost:1234", #line),
            (.init(userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any), host: "localhost", port: 1234), ";AUTH=*@localhost:1234", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIMAPServer($0) })
    }
}
