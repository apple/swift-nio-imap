//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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

class SequenceRangeSet_Tests: EncodeTestClass {}

// MARK: - sequenceRanges

extension SequenceRangeSet_Tests {
    func testSequenceRanges() {
        var testSet = MessageIdentifierSet<SequenceNumber>()
        XCTAssertEqual(testSet.ranges, [])

        _ = testSet.insert(1)
        XCTAssertEqual(testSet.ranges, [1])

        _ = testSet.insert(3)
        XCTAssertEqual(testSet.ranges, [1, 3])

        _ = testSet.insert(5)
        _ = testSet.insert(6)
        _ = testSet.insert(7)
        XCTAssertEqual(testSet.ranges, [1, 3, 5 ... 7])
    }
}
