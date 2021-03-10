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

class IAuthentication_Tests: EncodeTestClass {}

// MARK: - IMAP

extension IAuthentication_Tests {
    func testEncode() {
        let inputs: [(IAuthentication, String, UInt)] = [
            (.any, ";AUTH=*", #line),
            (.type(.init(authenticationType: "data")), ";AUTH=data", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIAuthentication($0) })
    }
}
