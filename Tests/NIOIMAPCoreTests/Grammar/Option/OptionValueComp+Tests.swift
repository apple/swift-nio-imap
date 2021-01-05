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

class OptionValueComp_Tests: EncodeTestClass {}

// MARK: - Encoding

extension OptionValueComp_Tests {
    func testEncode() {
        let inputs: [(OptionValues, String, UInt)] = [
            (["test"], "(\"test\")", #line),
            (["test1", "test2"], "(\"test1\" \"test2\")", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeOptionValue($0) } )
    }
}
