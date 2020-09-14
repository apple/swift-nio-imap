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

class ChangedSinceModifier_Tests: EncodeTestClass {}

// MARK: - Name/Values

extension ChangedSinceModifier_Tests {
    func testEncode() {
        let inputs: [(ChangedSinceModifier, String, UInt)] = [
            (.init(modifiedSequence: 3), "CHANGEDSINCE 3", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeChangedSinceModifier($0) })
    }
    
    func testEncode_unchanged() {
        let inputs: [(UnchangedSinceModifier, String, UInt)] = [
            (.init(modifiedSequence: 3), "UNCHANGEDSINCE 3", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeUnchangedSinceModifier($0) })
    }
}
