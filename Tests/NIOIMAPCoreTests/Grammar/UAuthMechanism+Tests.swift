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

class UAuthMechanism_Tests: EncodeTestClass {}

// MARK: - Encoding

extension UAuthMechanism_Tests {
    func testEncode() {
        let inputs: [(UAuthMechanism, String, UInt)] = [
            (.internal, "INTERNAL", #line),
            (.init(rawValue: "test"), "test", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUAuthMechanism($0) })
    }
}
