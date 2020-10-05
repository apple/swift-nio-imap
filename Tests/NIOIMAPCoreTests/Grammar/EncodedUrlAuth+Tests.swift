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

class EncodedUrlAuth_Tests: EncodeTestClass {}

// MARK: - Encoding

extension EncodedUrlAuth_Tests {
    func testEncode() {
        let inputs: [(EncodedUrlAuth, String, UInt)] = [
            (.init(data: "1F"), "1F", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeEncodedUrlAuth($0) })
    }
}
