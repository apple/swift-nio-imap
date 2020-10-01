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

class UIDValidity_Tests: EncodeTestClass {}

// MARK: - Encoding

extension UIDValidity_Tests {
    
    func testEncode() {
        let inputs: [(UIDValidity, String, UInt)] = [
            (.init(uid: 123)!, ";UIDVALIDITY=123", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUIDValidaty($0) })
    }
    
}
