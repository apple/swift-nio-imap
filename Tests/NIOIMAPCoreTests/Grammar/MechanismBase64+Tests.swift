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

class MechanismBase64_Tests: EncodeTestClass {}

// MARK: - Encoding

extension MechanismBase64_Tests {
    func testEncode() {
        let inputs: [(MechanismBase64, String, UInt)] = [
            (.init(mechanism: .internal, base64: nil), " INTERNAL", #line),
            (.init(mechanism: .internal, base64: "base64"), " INTERNAL=base64", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMechanismBase64($0) })
    }
}
