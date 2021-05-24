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

class ListSelectIndependentOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ListSelectIndependentOption_Tests {
    func testEncode() {
        let inputs: [(ListSelectIndependentOption, String, UInt)] = [
            (.remote, "REMOTE", #line),
            (.option(.init(key: .standard("test"), value: nil)), "test", #line),
            (.specialUse, "SPECIAL-USE", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeListSelectIndependentOption($0) })
    }
}
