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

class Access_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Access_Tests {
    func testEncoding() {
        let inputs: [(Access, String, UInt)] = [
            (.anonymous, "anonymous", #line),
            (.authenticateUser, "authuser", #line),
            (.submit(.init(data: "abc")), "submit+abc", #line),
            (.user(.init(data: "abc")), "user+abc", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeAccess($0) })
    }
}
