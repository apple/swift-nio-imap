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
import OrderedCollections
import XCTest

class ID_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ID_Tests {
    func testEncode() {
        let inputs: [(OrderedDictionary<String, String?>, String, UInt)] = [
            ([:], "NIL", #line),
            (["key": "value"], #"("key" "value")"#, #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIDParameters($0) })
    }
}
