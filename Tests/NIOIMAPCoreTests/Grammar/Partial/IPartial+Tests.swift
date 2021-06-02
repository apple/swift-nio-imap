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
import XCTest

class IPartial_Tests: EncodeTestClass {}

// MARK: - Encoding

extension IPartial_Tests {
    func testEncode_IPartial() {
        let inputs: [(IPartial, String, UInt)] = [
            (.init(range: .init(offset: 1, length: nil)), "/;PARTIAL=1", #line),
            (.init(range: .init(offset: 1, length: 2)), "/;PARTIAL=1.2", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeIPartial($0) })
    }
}
