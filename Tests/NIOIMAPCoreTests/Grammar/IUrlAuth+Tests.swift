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

class IURLAuth_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IURLAuth_Tests {
    func testEncode() {
        let inputs: [(IURLAuth, String, UInt)] = [
            (.init(auth: .init(access: .anonymous), verifier: .init(uAuthMechanism: .internal, encodedURLAuth: .init(data: "test"))), ";URLAUTH=anonymous:INTERNAL:test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIURLAuth($0) })
    }
}
