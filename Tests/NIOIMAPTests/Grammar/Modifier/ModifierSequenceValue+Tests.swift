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

import XCTest
import NIO
@testable import IMAPCore
@testable import NIOIMAP

class ModifierSequenceValue_Tests: EncodeTestClass {

    func testModifierSequenceValue_encode() {
        let inputs: [(IMAPCore.ModifierSequenceValue, String)] = ClosedRange(uncheckedBounds: (0, 10000)).map { num in
            return (.value(num), "\(num)")
        }

        for (test, expectedString) in inputs {
            self.testBuffer.clear()
            self.testBuffer.writeModifierSequenceValue(test)
            XCTAssertEqual(self.testBufferString, expectedString)
        }
    }
    
}
