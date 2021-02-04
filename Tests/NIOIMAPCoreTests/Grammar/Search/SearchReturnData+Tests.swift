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

class SearchReturnData_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SearchReturnData_Tests {
    func testEncode() {
        let inputs: [(SearchReturnData, String, UInt)] = [
            (.min(1), "MIN 1", #line),
            (.max(1), "MAX 1", #line),
            (.all(SequenceSet(1 ... 3)), "ALL 1:3", #line),
            (.count(1), "COUNT 1", #line),
            (.modificationSequence(1), "MODSEQ 1", #line),
            (.dataExtension(.init(key: "modifier", value: .sequence([3]))), "modifier 3", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSearchReturnData($0) })
    }
}
