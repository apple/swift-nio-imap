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

class SortData_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SortData_Tests {
    func testEncode() {
        let inputs: [(SortData?, String, UInt)] = [
            (nil, "SORT", #line),
            (.init(identifiers: [1], modificationSequence: .init(modifierSequenceValue: 2)), "SORT 1 (MODSEQ 2)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeSortData($0) })
    }
}
