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

class PartialRange_Tests: EncodeTestClass {}

// MARK: - Encoding

extension PartialRange_Tests {
    func testEncode() {
        let inputs: [(PartialRange, String, UInt)] = [
            (.init(offset: 1, length: nil), "1", #line),
            (.init(offset: 1, length: 2), "1.2", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writePartialRange($0) })
    }
}
